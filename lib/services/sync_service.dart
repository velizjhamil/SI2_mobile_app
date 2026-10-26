import 'dart:async';
import 'package:http/http.dart' as http;

import '../models/sync_model.dart';
import 'campo_service.dart';
import 'offline_store.dart';
import 'uuid_generator.dart';

class SyncService {
  final CampoService campoService;
  final OfflineStore store;
  Future<SyncResult>? _inFlightSync;

  SyncService({
    required this.campoService,
    required this.store,
  });

  Future<int> getPendingCount() async {
    final queue = await store.getQueue();
    return queue.length;
  }

  Future<int> getConflictsCount() async {
    final conflicts = await store.getConflicts();
    return conflicts.length;
  }

  Future<SyncResult> sync({http.Client? client}) {
    if (_inFlightSync != null) {
      return _inFlightSync!;
    }
    final future = _syncInternal(client: client);
    _inFlightSync = future;
    return future.whenComplete(() {
      _inFlightSync = null;
    });
  }

  Future<SyncResult> _syncInternal({http.Client? client}) async {
    final queue = await store.getQueue();
    if (queue.isEmpty) {
      final conflictCount = await getConflictsCount();
      return SyncResult(
        syncedCount: 0,
        pendingCount: 0,
        conflictsCount: conflictCount,
      );
    }

    int syncedCount = 0;

    // Track which solicitudIds still have pending evaluation saves
    final pendingEvalSolicitudIds = queue
        .where((i) =>
            i.kind == QueueItemKind.evaluationSave && i.solicitudId != null)
        .map((i) => i.solicitudId!)
        .toSet();

    for (final item in queue) {
      // Ordering rule: a photo for a request whose evaluation save is pending waits for it
      if (item.kind == QueueItemKind.photoUpload && item.solicitudId != null) {
        if (pendingEvalSolicitudIds.contains(item.solicitudId)) {
          // Evaluation save for this request is still pending; wait for it
          continue;
        }
      }

      CampoResult dynamicResult;

      switch (item.kind) {
        case QueueItemKind.evaluationSave:
          final form = item.evaluacionForm;
          if (form == null || item.solicitudId == null) {
            final conflict = SyncConflict(
              id: UuidGenerator.v4(),
              item: item,
              error:
                  'Elemento de cola malformado: falta solicitudId o formulario de evaluación.',
              statusCode: 422,
              timestamp: store.now(),
            );
            await store.addConflict(conflict);
            await store.removeQueueItem(item.id);
            continue;
          }
          dynamicResult = await campoService.guardarEvaluacion(
            item.solicitudId!,
            form,
            client: client,
          );
          break;

        case QueueItemKind.photoUpload:
          if (item.solicitudId == null || item.photoFilePath == null) {
            final conflict = SyncConflict(
              id: UuidGenerator.v4(),
              item: item,
              error:
                  'Elemento de cola malformado: falta solicitudId o ruta de foto.',
              statusCode: 422,
              timestamp: store.now(),
            );
            await store.addConflict(conflict);
            await store.removeQueueItem(item.id);
            continue;
          }
          final bytes = await store.readPhotoBytes(item.photoFilePath!);
          if (bytes == null) {
            // Photo file missing on disk; record conflict
            final conflict = SyncConflict(
              id: UuidGenerator.v4(),
              item: item,
              error:
                  'El archivo de la fotografía no se encuentra en el dispositivo.',
              statusCode: 404,
              timestamp: store.now(),
            );
            await store.addConflict(conflict);
            await store.removeQueueItem(item.id);
            continue;
          }
          dynamicResult = await campoService.subirFotoEvaluacion(
            item.solicitudId!,
            bytes: bytes,
            filename: item.filename ?? 'foto.jpg',
            clientId: item.clientId,
            client: client,
          );
          break;

        case QueueItemKind.photoDelete:
          if (item.solicitudId == null || item.fotoId == null) {
            final conflict = SyncConflict(
              id: UuidGenerator.v4(),
              item: item,
              error: 'Elemento de cola malformado: falta solicitudId o fotoId.',
              statusCode: 422,
              timestamp: store.now(),
            );
            await store.addConflict(conflict);
            await store.removeQueueItem(item.id);
            continue;
          }
          dynamicResult = await campoService.eliminarFotoEvaluacion(
            item.solicitudId!,
            item.fotoId!,
            client: client,
          );
          break;

        case QueueItemKind.prequalification:
          final form = item.precalificacionForm;
          if (form == null) {
            final conflict = SyncConflict(
              id: UuidGenerator.v4(),
              item: item,
              error:
                  'Elemento de cola malformado: falta formulario de precalificación.',
              statusCode: 422,
              timestamp: store.now(),
            );
            await store.addConflict(conflict);
            await store.removeQueueItem(item.id);
            continue;
          }
          dynamicResult = await campoService.precalificar(form, client: client);
          break;
      }

      // Check results
      if (dynamicResult.success) {
        await store.removeQueueItem(item.id);
        if (item.kind == QueueItemKind.evaluationSave &&
            item.solicitudId != null) {
          pendingEvalSolicitudIds.remove(item.solicitudId);
        }
        if (item.kind == QueueItemKind.photoUpload) {
          await store.deletePhotoFile(item.photoFilePath);
        }
        if (item.kind == QueueItemKind.prequalification &&
            dynamicResult.value != null) {
          await store.saveCompletedPrequalification(dynamicResult.value!);
        }
        syncedCount++;
        continue;
      }

      // 401 Unauthorized -> stop immediately and ask to sign in again
      if (dynamicResult.statusCode == 401) {
        final remaining = await store.getQueue();
        final currentConflicts = await getConflictsCount();
        return SyncResult(
          syncedCount: syncedCount,
          pendingCount: remaining.length,
          conflictsCount: currentConflicts,
          isUnauthorized: true,
          message: dynamicResult.error ?? 'Sesión no válida o expirada.',
        );
      }

      // 409 / 422 / 404 / 403 -> move to conflict list with server detail (server wins)
      final sc = dynamicResult.statusCode;
      if (sc == 409 || sc == 422 || sc == 404 || sc == 403) {
        final conflict = SyncConflict(
          id: UuidGenerator.v4(),
          item: item,
          error: dynamicResult.error ?? 'Error de validación o conflicto ($sc)',
          statusCode: sc!,
          timestamp: store.now(),
        );
        await store.addConflict(conflict);
        await store.removeQueueItem(item.id);
        if (item.kind == QueueItemKind.evaluationSave &&
            item.solicitudId != null) {
          pendingEvalSolicitudIds.remove(item.solicitudId);
        }
        // Do NOT delete photo file on conflict! Retain bytes until conflict is discarded.
        continue;
      }

      // Network failure -> stays queued, halt this sync pass
      if (dynamicResult.isNetworkError) {
        final remaining = await store.getQueue();
        final currentConflicts = await getConflictsCount();
        return SyncResult(
          syncedCount: syncedCount,
          pendingCount: remaining.length,
          conflictsCount: currentConflicts,
          isNetworkError: true,
          message: dynamicResult.error ??
              'Sin conexión al servidor. Los elementos continúan en cola.',
        );
      }

      // Any other server error (e.g. 500) -> stays queued (never drop silently)
    }

    final remaining = await store.getQueue();
    final totalConflicts = await getConflictsCount();
    return SyncResult(
      syncedCount: syncedCount,
      pendingCount: remaining.length,
      conflictsCount: totalConflicts,
    );
  }
}
