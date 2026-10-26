import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/campo_model.dart';
import '../models/sync_model.dart';
import 'mock_auth_service.dart';
import 'uuid_generator.dart';

class _AsyncLock {
  Future<void> _last = Future.value();

  Future<T> synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _last = _last.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}

class OfflineStore {
  final Directory baseDirectory;
  final String userId;
  final DateTime Function() now;
  final _AsyncLock _lock = _AsyncLock();

  OfflineStore({
    required this.baseDirectory,
    required this.userId,
    DateTime Function()? now,
  })  : assert(userId.isNotEmpty, 'userId must not be empty'),
        now = now ?? DateTime.now;

  static Future<OfflineStore?> create({
    Directory? baseDirectory,
    String? userId,
    DateTime Function()? now,
  }) async {
    final uid = userId ?? AuthService.currentUserId;
    if (uid == null || uid.isEmpty) {
      return null;
    }
    final dir = baseDirectory ?? await getApplicationDocumentsDirectory();
    return OfflineStore(
      baseDirectory: dir,
      userId: uid,
      now: now,
    );
  }

  Directory get _userDir {
    final dir = Directory('${baseDirectory.path}/offline_store/$userId');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<void> _writeJsonAtomic(String relativePath, dynamic data) async {
    final targetFile = File('${_userDir.path}/$relativePath');
    final parent = targetFile.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final tempFile = File(
      '${targetFile.path}.tmp_${DateTime.now().microsecondsSinceEpoch}_${UuidGenerator.v4()}',
    );
    await tempFile.writeAsString(jsonEncode(data), flush: true);
    await tempFile.rename(targetFile.path);
  }

  Future<dynamic> _readJson(String relativePath) async {
    final file = File('${_userDir.path}/$relativePath');
    if (!file.existsSync()) return null;
    final content = await file.readAsString();
    if (content.trim().isEmpty) return null;
    try {
      return jsonDecode(content);
    } catch (e) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final corruptFile = File('${file.path}.corrupt-$timestamp');
      try {
        await file.rename(corruptFile.path);
      } catch (_) {}
      try {
        final noticeFile = File('${_userDir.path}/corrupt_notice.flag');
        await noticeFile.writeAsString(corruptFile.path, flush: true);
      } catch (_) {}
      // Return null so callers continue with empty state without failing
      return null;
    }
  }

  Future<bool> hasCorruptNotice() async {
    final noticeFile = File('${_userDir.path}/corrupt_notice.flag');
    return noticeFile.existsSync();
  }

  Future<void> clearCorruptNotice() async {
    final noticeFile = File('${_userDir.path}/corrupt_notice.flag');
    if (noticeFile.existsSync()) {
      try {
        await noticeFile.delete();
      } catch (_) {}
    }
  }

  // --- Read Cache ---

  Future<void> saveWorklist(
    List<SolicitudResumenCampo> items, {
    String filterKey = 'TODOS',
  }) =>
      _lock.synchronized(() async {
        final key = filterKey.toUpperCase();
        await _writeJsonAtomic('cache/worklist_$key.json', {
          'timestamp': now().toIso8601String(),
          'data': items.map((i) => i.toJson()).toList(),
        });
      });

  Future<CachedData<List<SolicitudResumenCampo>>?> getWorklist({
    String filterKey = 'TODOS',
  }) =>
      _lock.synchronized(() async {
        final key = filterKey.toUpperCase();
        var json = await _readJson('cache/worklist_$key.json');
        if (json == null || json is! Map) {
          if (key == 'TODOS') {
            json = await _readJson('cache/worklist.json');
          }
        }
        if (json is! Map) return null;
        final timestamp =
            DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? now();
        final list = (json['data'] as List? ?? [])
            .whereType<Map>()
            .map((e) =>
                SolicitudResumenCampo.fromJson(e.cast<String, dynamic>()))
            .toList();
        return CachedData(data: list, timestamp: timestamp);
      });

  Future<void> saveFicha(int solicitudId, FichaCampo ficha) =>
      _lock.synchronized(() async {
        await _writeJsonAtomic('cache/fichas/$solicitudId.json', {
          'timestamp': now().toIso8601String(),
          'data': ficha.toJson(),
        });
      });

  Future<CachedData<FichaCampo>?> getFicha(int solicitudId) =>
      _lock.synchronized(() async {
        final json = await _readJson('cache/fichas/$solicitudId.json');
        if (json is! Map) return null;
        final timestamp = DateTime.parse(json['timestamp'] as String);
        final data = json['data'] as Map? ?? {};
        return CachedData(
          data: FichaCampo.fromJson(data.cast<String, dynamic>()),
          timestamp: timestamp,
        );
      });

  Future<void> saveSocios(List<SocioPrecalificacion> socios) =>
      _lock.synchronized(() async {
        await _writeJsonAtomic('cache/socios.json', {
          'timestamp': now().toIso8601String(),
          'data': socios.map((s) => s.toJson()).toList(),
        });
      });

  Future<CachedData<List<SocioPrecalificacion>>?> getSocios() =>
      _lock.synchronized(() async {
        final json = await _readJson('cache/socios.json');
        if (json is! Map) return null;
        final timestamp = DateTime.parse(json['timestamp'] as String);
        final list = (json['data'] as List? ?? [])
            .whereType<Map>()
            .map((e) =>
                SocioPrecalificacion.fromJson(e.cast<String, dynamic>()))
            .toList();
        return CachedData(data: list, timestamp: timestamp);
      });

  Future<void> saveProductos(List<ProductoPrecalificacion> productos) =>
      _lock.synchronized(() async {
        await _writeJsonAtomic('cache/productos.json', {
          'timestamp': now().toIso8601String(),
          'data': productos.map((p) => p.toJson()).toList(),
        });
      });

  Future<CachedData<List<ProductoPrecalificacion>>?> getProductos() =>
      _lock.synchronized(() async {
        final json = await _readJson('cache/productos.json');
        if (json is! Map) return null;
        final timestamp = DateTime.parse(json['timestamp'] as String);
        final list = (json['data'] as List? ?? [])
            .whereType<Map>()
            .map((e) =>
                ProductoPrecalificacion.fromJson(e.cast<String, dynamic>()))
            .toList();
        return CachedData(data: list, timestamp: timestamp);
      });

  // --- Queue Operations ---

  Future<List<QueueItem>> _getQueueInternal() async {
    final json = await _readJson('queue.json');
    if (json == null) return [];
    if (json is! List) return [];
    return json
        .whereType<Map>()
        .map((e) => QueueItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<QueueItem>> getQueue() => _lock.synchronized(() async {
        return _getQueueInternal();
      });

  Future<void> saveQueue(List<QueueItem> items) =>
      _lock.synchronized(() async {
        await _writeJsonAtomic(
          'queue.json',
          items.map((i) => i.toJson()).toList(),
        );
      });

  Future<void> enqueue(QueueItem item) => _lock.synchronized(() async {
        final queue = await _getQueueInternal();
        queue.add(item);
        await _writeJsonAtomic(
          'queue.json',
          queue.map((i) => i.toJson()).toList(),
        );
      });

  Future<void> enqueueOrReplaceEvaluationSave(QueueItem item) =>
      _lock.synchronized(() async {
        final queue = await _getQueueInternal();
        final existingIdx = queue.indexWhere((i) =>
            i.kind == QueueItemKind.evaluationSave &&
            i.solicitudId == item.solicitudId);
        if (existingIdx != -1) {
          queue[existingIdx] = item;
        } else {
          queue.add(item);
        }
        await _writeJsonAtomic(
          'queue.json',
          queue.map((i) => i.toJson()).toList(),
        );
      });

  Future<void> removeEvaluationSavesForSolicitud(int solicitudId) =>
      _lock.synchronized(() async {
        final queue = await _getQueueInternal();
        queue.removeWhere((i) =>
            i.kind == QueueItemKind.evaluationSave &&
            i.solicitudId == solicitudId);
        await _writeJsonAtomic(
          'queue.json',
          queue.map((i) => i.toJson()).toList(),
        );
      });

  Future<void> updateQueueItem(QueueItem item) => _lock.synchronized(() async {
        final queue = await _getQueueInternal();
        final idx = queue.indexWhere((i) => i.id == item.id);
        if (idx != -1) {
          queue[idx] = item;
          await _writeJsonAtomic(
            'queue.json',
            queue.map((i) => i.toJson()).toList(),
          );
        }
      });

  Future<void> removeQueueItem(String itemId) => _lock.synchronized(() async {
        final queue = await _getQueueInternal();
        queue.removeWhere((i) => i.id == itemId);
        await _writeJsonAtomic(
          'queue.json',
          queue.map((i) => i.toJson()).toList(),
        );
      });

  Future<void> clearQueue() => _lock.synchronized(() async {
        await _writeJsonAtomic('queue.json', []);
      });

  // --- Photo Files ---

  Future<String> savePhotoBytes(
    String clientId,
    List<int> bytes,
    String filename,
  ) async {
    final photosDir = Directory('${_userDir.path}/photos');
    if (!photosDir.existsSync()) {
      photosDir.createSync(recursive: true);
    }
    final ext = filename.contains('.') ? filename.split('.').last : 'jpg';
    final filePath = '${photosDir.path}/$clientId.$ext';
    await File(filePath).writeAsBytes(bytes, flush: true);
    return filePath;
  }

  Future<List<int>?> readPhotoBytes(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;
    return await file.readAsBytes();
  }

  Future<void> deletePhotoFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    final file = File(filePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  // --- Conflict Operations ---

  Future<List<SyncConflict>> _getConflictsInternal() async {
    final json = await _readJson('conflicts.json');
    if (json == null) return [];
    if (json is! List) return [];
    return json
        .whereType<Map>()
        .map((e) => SyncConflict.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<SyncConflict>> getConflicts() => _lock.synchronized(() async {
        return _getConflictsInternal();
      });

  Future<void> saveConflicts(List<SyncConflict> conflicts) =>
      _lock.synchronized(() async {
        await _writeJsonAtomic(
          'conflicts.json',
          conflicts.map((c) => c.toJson()).toList(),
        );
      });

  Future<void> addConflict(SyncConflict conflict) =>
      _lock.synchronized(() async {
        final list = await _getConflictsInternal();
        list.add(conflict);
        await _writeJsonAtomic(
          'conflicts.json',
          list.map((c) => c.toJson()).toList(),
        );
      });

  Future<void> removeConflict(String conflictId) =>
      _lock.synchronized(() async {
        final list = await _getConflictsInternal();
        final toRemove = list.where((c) => c.id == conflictId).toList();
        for (final c in toRemove) {
          if (c.item.kind == QueueItemKind.photoUpload) {
            await deletePhotoFile(c.item.photoFilePath);
          }
        }
        list.removeWhere((c) => c.id == conflictId);
        await _writeJsonAtomic(
          'conflicts.json',
          list.map((c) => c.toJson()).toList(),
        );
      });

  Future<void> clearConflicts() => _lock.synchronized(() async {
        final list = await _getConflictsInternal();
        for (final c in list) {
          if (c.item.kind == QueueItemKind.photoUpload) {
            await deletePhotoFile(c.item.photoFilePath);
          }
        }
        await _writeJsonAtomic('conflicts.json', []);
      });

  // --- Completed Prequalifications ---

  Future<List<PrecalificacionResultado>>
      _getCompletedPrequalificationsInternal() async {
    final json = await _readJson('precalificaciones_completadas.json');
    if (json == null) return [];
    if (json is! List) return [];
    return json
        .whereType<Map>()
        .map((e) =>
            PrecalificacionResultado.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<PrecalificacionResultado>> getCompletedPrequalifications() =>
      _lock.synchronized(() async {
        return _getCompletedPrequalificationsInternal();
      });

  Future<void> saveCompletedPrequalification(
    PrecalificacionResultado result,
  ) =>
      _lock.synchronized(() async {
        final list = await _getCompletedPrequalificationsInternal();
        if (result.clientId != null && result.clientId!.isNotEmpty) {
          final existingIdx =
              list.indexWhere((r) => r.clientId == result.clientId);
          if (existingIdx != -1) {
            list[existingIdx] = result;
            await _writeJsonAtomic(
              'precalificaciones_completadas.json',
              list.map((r) => r.toJson()).toList(),
            );
            return;
          }
        }
        list.add(result);
        await _writeJsonAtomic(
          'precalificaciones_completadas.json',
          list.map((r) => r.toJson()).toList(),
        );
      });
}
