import 'dart:async';
import 'package:http/http.dart' as http;

import '../models/campo_model.dart';
import '../models/sync_model.dart';
import 'campo_service.dart';
import 'offline_store.dart';
import 'sync_service.dart';
import 'uuid_generator.dart';

class SyncCampoService extends CampoService {
  final CampoService innerService;
  final OfflineStore store;
  late final SyncService syncService;

  DateTime? lastWorklistCacheTime;
  bool isWorklistOffline = false;

  DateTime? lastFichaCacheTime;
  bool isFichaOffline = false;

  DateTime? lastSociosCacheTime;
  bool isSociosOffline = false;

  DateTime? lastProductosCacheTime;
  bool isProductosOffline = false;

  SyncCampoService({
    CampoService? innerService,
    required this.store,
    SyncService? syncService,
  })  : innerService = innerService ?? CampoService() {
    this.syncService = syncService ??
        SyncService(
          campoService: this.innerService,
          store: store,
        );
  }

  @override
  Future<CampoResult<List<SolicitudResumenCampo>>> getWorklist({
    bool requiereEvaluacion = true,
    String? canalOrigen,
    http.Client? client,
  }) async {
    final result = await innerService.getWorklist(
      requiereEvaluacion: requiereEvaluacion,
      canalOrigen: canalOrigen,
      client: client,
    );

    if (result.success && result.value != null) {
      isWorklistOffline = false;
      lastWorklistCacheTime = null;
      await store.saveWorklist(result.value!);
      return result;
    }

    if (result.isNetworkError) {
      final cached = await store.getWorklist();
      if (cached != null) {
        isWorklistOffline = true;
        lastWorklistCacheTime = cached.timestamp;
        var items = cached.data;
        if (canalOrigen != null &&
            canalOrigen.isNotEmpty &&
            canalOrigen != 'TODOS') {
          items = items.where((i) => i.canalOrigen == canalOrigen).toList();
        }
        return CampoResult.success(items);
      }
    }

    return result;
  }

  @override
  Future<CampoResult<FichaCampo>> getFichaCampo(
    int solicitudId, {
    http.Client? client,
  }) async {
    final result = await innerService.getFichaCampo(
      solicitudId,
      client: client,
    );

    if (result.success && result.value != null) {
      isFichaOffline = false;
      lastFichaCacheTime = null;
      await store.saveFicha(solicitudId, result.value!);
      return result;
    }

    if (result.isNetworkError) {
      final cached = await store.getFicha(solicitudId);
      if (cached != null) {
        isFichaOffline = true;
        lastFichaCacheTime = cached.timestamp;
        return CampoResult.success(cached.data);
      }
    }

    return result;
  }

  @override
  Future<CampoResult<List<SocioPrecalificacion>>> getSociosActivos({
    http.Client? client,
  }) async {
    final result = await innerService.getSociosActivos(client: client);
    if (result.success && result.value != null) {
      isSociosOffline = false;
      lastSociosCacheTime = null;
      await store.saveSocios(result.value!);
      return result;
    }

    if (result.isNetworkError) {
      final cached = await store.getSocios();
      if (cached != null) {
        isSociosOffline = true;
        lastSociosCacheTime = cached.timestamp;
        return CampoResult.success(cached.data);
      }
    }

    return result;
  }

  @override
  Future<CampoResult<List<ProductoPrecalificacion>>> getProductosActivos({
    http.Client? client,
  }) async {
    final result = await innerService.getProductosActivos(client: client);
    if (result.success && result.value != null) {
      isProductosOffline = false;
      lastProductosCacheTime = null;
      await store.saveProductos(result.value!);
      return result;
    }

    if (result.isNetworkError) {
      final cached = await store.getProductos();
      if (cached != null) {
        isProductosOffline = true;
        lastProductosCacheTime = cached.timestamp;
        return CampoResult.success(cached.data);
      }
    }

    return result;
  }

  @override
  Future<CampoResult<SolicitudResumenCampo>> guardarEvaluacion(
    int solicitudId,
    EvaluacionCampoForm form, {
    http.Client? client,
  }) async {
    final result = await innerService.guardarEvaluacion(
      solicitudId,
      form,
      client: client,
    );

    if (result.success) {
      unawaited(syncService.sync(client: client));
      return result;
    }

    if (result.isNetworkError) {
      final item = QueueItem(
        id: UuidGenerator.v4(),
        kind: QueueItemKind.evaluationSave,
        solicitudId: solicitudId,
        createdAt: store.now(),
        payload: form.toJson(),
      );
      await store.enqueue(item);
      return const CampoResult.failure(
        'Sin conexión. Evaluación en cola (Pendiente de sincronizar).',
        isNetworkError: true,
      );
    }

    return result;
  }

  @override
  Future<CampoResult<List<FotoEvaluacionCampo>>> subirFotoEvaluacion(
    int solicitudId, {
    required List<int> bytes,
    required String filename,
    String? clientId,
    http.Client? client,
  }) async {
    final cid = clientId ?? UuidGenerator.v4();

    final result = await innerService.subirFotoEvaluacion(
      solicitudId,
      bytes: bytes,
      filename: filename,
      clientId: cid,
      client: client,
    );

    if (result.success) {
      unawaited(syncService.sync(client: client));
      return result;
    }

    if (result.isNetworkError) {
      final filePath = await store.savePhotoBytes(cid, bytes, filename);
      final item = QueueItem(
        id: UuidGenerator.v4(),
        kind: QueueItemKind.photoUpload,
        solicitudId: solicitudId,
        createdAt: store.now(),
        payload: {
          'client_id': cid,
          'photo_file_path': filePath,
          'filename': filename,
        },
      );
      await store.enqueue(item);
      return const CampoResult.failure(
        'Sin conexión. Fotografía en cola (Pendiente de sincronizar).',
        isNetworkError: true,
      );
    }

    return result;
  }

  @override
  Future<CampoResult<List<FotoEvaluacionCampo>>> eliminarFotoEvaluacion(
    int solicitudId,
    String fotoId, {
    http.Client? client,
  }) async {
    final result = await innerService.eliminarFotoEvaluacion(
      solicitudId,
      fotoId,
      client: client,
    );

    if (result.success) {
      unawaited(syncService.sync(client: client));
      return result;
    }

    if (result.isNetworkError) {
      final item = QueueItem(
        id: UuidGenerator.v4(),
        kind: QueueItemKind.photoDelete,
        solicitudId: solicitudId,
        createdAt: store.now(),
        payload: {'foto_id': fotoId},
      );
      await store.enqueue(item);
      return const CampoResult.failure(
        'Sin conexión. Eliminación en cola (Pendiente de sincronizar).',
        isNetworkError: true,
      );
    }

    return result;
  }

  @override
  Future<CampoResult<PrecalificacionResultado>> precalificar(
    PrecalificacionForm form, {
    http.Client? client,
  }) async {
    final result = await innerService.precalificar(form, client: client);

    if (result.success) {
      unawaited(syncService.sync(client: client));
      return result;
    }

    if (result.isNetworkError) {
      final item = QueueItem(
        id: UuidGenerator.v4(),
        kind: QueueItemKind.prequalification,
        createdAt: store.now(),
        payload: form.toJson(),
      );
      await store.enqueue(item);
      return const CampoResult.failure(
        'Sin conexión. Precalificación en cola (Pendiente de sincronizar).',
        isNetworkError: true,
      );
    }

    return result;
  }

  @override
  Future<CampoResult<ScoringResultado>> calcularScoring(
    int solicitudId, {
    http.Client? client,
  }) async {
    return innerService.calcularScoring(solicitudId, client: client);
  }

  @override
  Future<CampoResult<List<FotoEvaluacionCampo>>> getFotosEvaluacion(
    int solicitudId, {
    http.Client? client,
  }) async {
    return innerService.getFotosEvaluacion(solicitudId, client: client);
  }
}
