import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:forest_microfinance/models/campo_model.dart';
import 'package:forest_microfinance/models/sync_model.dart';
import 'package:forest_microfinance/services/campo_service.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/offline_store.dart';
import 'package:forest_microfinance/services/sync_campo_service.dart';
import 'package:forest_microfinance/services/sync_service.dart';
import 'package:forest_microfinance/services/uuid_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  DateTime testTime = DateTime(2026, 10, 26, 9, 30);
  DateTime mockClock() => testTime;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_test_');
    AuthService.tokenJWT = 'test-token-jwt';
  });

  tearDown(() async {
    AuthService.tokenJWT = null;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CU-M11 Offline Sync Unit & Integration Tests', () {
    test('UuidGenerator produces valid RFC 4122 UUID v4 strings', () {
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      for (int i = 0; i < 50; i++) {
        final uuid = UuidGenerator.v4();
        expect(uuid.length, 36);
        expect(
          uuidRegex.hasMatch(uuid),
          isTrue,
          reason: 'Generated UUID "$uuid" does not match UUID v4 regex',
        );
      }
    });

    test('OfflineStore - persistence across restart', () async {
      final store1 = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_1',
        now: mockClock,
      );

      const evaluacionForm = EvaluacionCampoForm(
        ingresoMensual: '5000.00',
        egresoMensual: '2000.00',
        cuotaDeudasMensual: '500.00',
        actividadEconomica: 'Comercio',
        fuenteIngresos: 'INDEPENDIENTE',
        antiguedadLaboralMeses: 24,
        calificacionAsfi: 'A',
      );

      final queueItem = QueueItem(
        id: UuidGenerator.v4(),
        kind: QueueItemKind.evaluationSave,
        solicitudId: 101,
        createdAt: testTime,
        payload: evaluacionForm.toJson(),
      );

      await store1.enqueue(queueItem);

      const worklistItem = SolicitudResumenCampo(
        id: 101,
        numeroSolicitud: 'SOL-101',
        fechaSolicitud: '2026-10-25',
        estado: 'PENDIENTE_EVALUACION',
        socioNombre: 'Juan Perez',
        socioCi: '1234567',
        productoNombre: 'Microcrédito',
        monedaSimbolo: 'Bs.',
        monto: '10000.00',
        plazoMeses: 12,
        destino: 'Capital de trabajo',
        canalOrigen: 'MOVIL',
        requiereEvaluacion: true,
      );

      await store1.saveWorklist([worklistItem]);

      // Simulate app restart by instantiating a new store pointing to the same directory
      final store2 = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_1',
        now: mockClock,
      );

      final queue = await store2.getQueue();
      expect(queue.length, 1);
      expect(queue.first.id, queueItem.id);
      expect(queue.first.kind, QueueItemKind.evaluationSave);
      expect(queue.first.solicitudId, 101);
      expect(queue.first.evaluacionForm?.ingresoMensual, '5000.00');

      final cachedWorklist = await store2.getWorklist();
      expect(cachedWorklist, isNotNull);
      expect(cachedWorklist!.data.length, 1);
      expect(cachedWorklist.data.first.numeroSolicitud, 'SOL-101');
      expect(cachedWorklist.timestamp, testTime);
    });

    test('OfflineStore - user isolation', () async {
      final storeUserA = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_A',
        now: mockClock,
      );
      final storeUserB = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_B',
        now: mockClock,
      );

      final itemA = QueueItem(
        id: 'item-user-a',
        kind: QueueItemKind.prequalification,
        createdAt: testTime,
        payload: {
          'socio_id': 1,
          'producto_id': 2,
          'monto': '5000.00',
          'plazo_meses': 12,
          'ingreso_mensual': '3000.00',
          'egreso_mensual': '1000.00',
          'cuota_deudas_mensual': '0.00',
          'antiguedad_laboral_meses': 12,
        },
      );

      await storeUserA.enqueue(itemA);

      // User B must NOT see User A's queue
      final queueB = await storeUserB.getQueue();
      expect(queueB, isEmpty);

      // User B queues their own item
      final itemB = QueueItem(
        id: 'item-user-b',
        kind: QueueItemKind.photoDelete,
        solicitudId: 50,
        createdAt: testTime,
        payload: {'foto_id': '1/2/photo.jpg'},
      );
      await storeUserB.enqueue(itemB);

      // Queues remain isolated
      final finalQueueA = await storeUserA.getQueue();
      final finalQueueB = await storeUserB.getQueue();

      expect(finalQueueA.map((i) => i.id), ['item-user-a']);
      expect(finalQueueB.map((i) => i.id), ['item-user-b']);
    });

    test('SyncService - FIFO and photo-after-evaluation ordering', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_order',
        now: mockClock,
      );

      // Save a dummy photo file
      final photoPath = await store.savePhotoBytes(
        'photo-uuid-1',
        [1, 2, 3, 4],
        'foto.jpg',
      );

      // Queue items in order:
      // 1. Photo upload for solicitud 10 (which must wait for eval 10)
      // 2. Evaluation save for solicitud 10
      // 3. Evaluation save for solicitud 20
      final photoItem10 = QueueItem(
        id: 'item-photo-10',
        kind: QueueItemKind.photoUpload,
        solicitudId: 10,
        createdAt: testTime,
        payload: {
          'client_id': 'photo-uuid-1',
          'photo_file_path': photoPath,
          'filename': 'foto.jpg',
        },
      );

      final evalItem10 = QueueItem(
        id: 'item-eval-10',
        kind: QueueItemKind.evaluationSave,
        solicitudId: 10,
        createdAt: testTime,
        payload: const EvaluacionCampoForm(
          ingresoMensual: '4000.00',
          egresoMensual: '1500.00',
          cuotaDeudasMensual: '0.00',
          actividadEconomica: 'Servicios',
          fuenteIngresos: 'DEPENDIENTE',
          antiguedadLaboralMeses: 36,
          calificacionAsfi: 'A',
        ).toJson(),
      );

      final evalItem20 = QueueItem(
        id: 'item-eval-20',
        kind: QueueItemKind.evaluationSave,
        solicitudId: 20,
        createdAt: testTime,
        payload: const EvaluacionCampoForm(
          ingresoMensual: '7000.00',
          egresoMensual: '2500.00',
          cuotaDeudasMensual: '0.00',
          actividadEconomica: 'Producción',
          fuenteIngresos: 'INDEPENDIENTE',
          antiguedadLaboralMeses: 60,
          calificacionAsfi: 'A',
        ).toJson(),
      );

      await store.saveQueue([photoItem10, evalItem10, evalItem20]);

      final dispatchedRequests = <String>[];

      final mockClient = MockClient((request) async {
        dispatchedRequests.add('${request.method} ${request.url.path}');
        if (request.url.path.contains('/solicitudes/10/evaluacion/fotos')) {
          return http.Response(
            jsonEncode([
              {'id': '10/photo-uuid-1.jpg', 'url': 'http://test/p.jpg'}
            ]),
            201,
          );
        }
        if (request.url.path.contains('/solicitudes/10')) {
          return http.Response(
            jsonEncode({
              'id': 10,
              'numero_solicitud': 'SOL-10',
              'fecha_solicitud': '2026-10-26',
              'estado': 'EVALUACION_CAMPO',
              'monto': '8000.00',
              'plazo_meses': 12,
              'destino': 'Consumo',
              'canal_origen': 'MOVIL',
              'requiere_evaluacion': false,
            }),
            200,
          );
        }
        if (request.url.path.contains('/solicitudes/20')) {
          return http.Response(
            jsonEncode({
              'id': 20,
              'numero_solicitud': 'SOL-20',
              'fecha_solicitud': '2026-10-26',
              'estado': 'EVALUACION_CAMPO',
              'monto': '15000.00',
              'plazo_meses': 24,
              'destino': 'Negocio',
              'canal_origen': 'VENTANILLA',
              'requiere_evaluacion': false,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      final result = await syncService.sync(client: mockClient);

      // In the first pass:
      // - photoItem10 was skipped because evalItem10 was pending.
      // - evalItem10 was executed and succeeded!
      // - evalItem20 was executed and succeeded!
      // Note: photoItem10 remained because it waited.
      expect(dispatchedRequests, [
        'PUT /api/v1/creditos/solicitudes/10',
        'PUT /api/v1/creditos/solicitudes/20',
      ]);
      expect(result.syncedCount, 2);
      expect(result.pendingCount, 1);

      // Now run sync again: evalItem10 is done, so photoItem10 proceeds!
      dispatchedRequests.clear();
      final result2 = await syncService.sync(client: mockClient);
      expect(dispatchedRequests, [
        'POST /api/v1/creditos/solicitudes/10/evaluacion/fotos',
      ]);
      expect(result2.syncedCount, 1);
      expect(result2.pendingCount, 0);

      // Queue is now empty and photo file was deleted
      expect(await store.getQueue(), isEmpty);
      expect(File(photoPath).existsSync(), isFalse);
    });

    test('SyncService - Replay sends the same X-Client-Id', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_replay',
        now: mockClock,
      );

      final photoPath = await store.savePhotoBytes(
        '550e8400-e29b-41d4-a716-446655440000',
        [9, 8, 7],
        'photo.jpg',
      );

      final photoItem = QueueItem(
        id: 'photo-replay-item',
        kind: QueueItemKind.photoUpload,
        solicitudId: 99,
        createdAt: testTime,
        payload: {
          'client_id': '550e8400-e29b-41d4-a716-446655440000',
          'photo_file_path': photoPath,
          'filename': 'photo.jpg',
        },
      );
      await store.enqueue(photoItem);

      final capturedClientIds = <String?>[];
      int callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        capturedClientIds.add(request.headers['X-Client-Id']);

        if (callCount == 1) {
          // Simulate lost connection right after backend processing
          throw const SocketException('Connection lost');
        }

        // Replay: backend returns 200 with the already-uploaded photo
        return http.Response(
          jsonEncode([
            {
              'id': '99/550e8400-e29b-41d4-a716-446655440000.jpg',
              'url': 'http://test/view.jpg',
            }
          ]),
          200,
        );
      });

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      // Attempt 1: fails with network error
      final res1 = await syncService.sync(client: mockClient);
      expect(res1.isNetworkError, isTrue);
      expect(res1.pendingCount, 1);
      expect(capturedClientIds[0], '550e8400-e29b-41d4-a716-446655440000');
      expect(await store.getQueue(), isNotEmpty);

      // Attempt 2: replay with same X-Client-Id
      final res2 = await syncService.sync(client: mockClient);
      expect(res2.syncedCount, 1);
      expect(res2.pendingCount, 0);
      expect(capturedClientIds[1], '550e8400-e29b-41d4-a716-446655440000');

      // Assert identical UUID was sent in both attempts
      expect(capturedClientIds[0], equals(capturedClientIds[1]));
      expect(await store.getQueue(), isEmpty);
    });

    test('SyncService - Conflict routing (409, 422, 404, 403)', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_conflicts',
        now: mockClock,
      );

      final evalItem = QueueItem(
        id: 'eval-conflict-item',
        kind: QueueItemKind.evaluationSave,
        solicitudId: 77,
        createdAt: testTime,
        payload: const EvaluacionCampoForm(
          ingresoMensual: '5000.00',
          egresoMensual: '2000.00',
          cuotaDeudasMensual: '0.00',
          actividadEconomica: 'Comercio',
          fuenteIngresos: 'INDEPENDIENTE',
          antiguedadLaboralMeses: 12,
          calificacionAsfi: 'A',
        ).toJson(),
      );
      await store.enqueue(evalItem);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'La solicitud ya no se puede modificar',
          }),
          409,
        );
      });

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      final result = await syncService.sync(client: mockClient);

      // Removed from queue
      expect(result.conflictsCount, 1);
      expect(result.pendingCount, 0);
      expect(await store.getQueue(), isEmpty);

      // Moved to conflicts list
      final conflicts = await store.getConflicts();
      expect(conflicts.length, 1);
      final c = conflicts.first;
      expect(c.statusCode, 409);
      expect(c.error, 'La solicitud ya no se puede modificar');
      expect(c.item.id, 'eval-conflict-item');

      // User discards conflict
      await store.removeConflict(c.id);
      expect(await store.getConflicts(), isEmpty);
    });

    test('SyncService - 401 stop halts queue and preserves items', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_401',
        now: mockClock,
      );

      final item1 = QueueItem(
        id: 'item-1',
        kind: QueueItemKind.photoDelete,
        solicitudId: 10,
        createdAt: testTime,
        payload: {'foto_id': '1/photo1.jpg'},
      );
      final item2 = QueueItem(
        id: 'item-2',
        kind: QueueItemKind.photoDelete,
        solicitudId: 20,
        createdAt: testTime,
        payload: {'foto_id': '2/photo2.jpg'},
      );

      await store.saveQueue([item1, item2]);

      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({'detail': 'Token expirado'}),
          401,
        );
      });

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      final result = await syncService.sync(client: mockClient);

      expect(result.isUnauthorized, isTrue);
      // Execution stopped immediately on first item
      expect(callCount, 1);

      // Both items MUST remain in the queue
      final remainingQueue = await store.getQueue();
      expect(remainingQueue.length, 2);
      expect(remainingQueue[0].id, 'item-1');
      expect(remainingQueue[1].id, 'item-2');
      // No conflicts created for 401
      expect(await store.getConflicts(), isEmpty);
    });

    test('SyncService - Prequalification result is stored upon 2xx', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_precal',
        now: mockClock,
      );

      final precalItem = QueueItem(
        id: 'precal-item-1',
        kind: QueueItemKind.prequalification,
        createdAt: testTime,
        payload: {
          'socio_id': 3,
          'producto_id': 2,
          'monto': '8000.00',
          'plazo_meses': 24,
          'ingreso_mensual': '6000.00',
          'egreso_mensual': '2000.00',
          'cuota_deudas_mensual': '0.00',
          'antiguedad_laboral_meses': 48,
        },
      );
      await store.enqueue(precalItem);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'precalificacion': true,
            'score': 910,
            'dictamen': 'APROBADO',
            'cuota_estimada': '399.39',
            'relacion_cuota_ingreso': '6.66',
            'probabilidad_mora': '0.0492',
            'nivel_riesgo': 'BAJO',
            'factores': [],
            'knockouts': [],
            'socio': {'id': 3, 'nombre_completo': 'Sofia Socia', 'ci': '5551234'},
            'producto': {'id': 2, 'nombre': 'Crédito de Consumo'},
          }),
          200,
        );
      });

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      final result = await syncService.sync(client: mockClient);

      expect(result.syncedCount, 1);
      expect(await store.getQueue(), isEmpty);

      final completed = await store.getCompletedPrequalifications();
      expect(completed.length, 1);
      expect(completed.first.score, 910);
      expect(completed.first.dictamen, 'APROBADO');
      expect(completed.first.socioNombre, 'Sofia Socia');
    });

    test('SyncCampoService serves cached worklist and ficha on network failure', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_cache_test',
        now: mockClock,
      );

      // Populate cache
      const cachedWorklist = [
        SolicitudResumenCampo(
          id: 55,
          numeroSolicitud: 'SOL-55',
          fechaSolicitud: '2026-10-25',
          estado: 'PENDIENTE_EVALUACION',
          socioNombre: 'Carlos Gomez',
          socioCi: '998877',
          productoNombre: 'Consumo',
          monedaSimbolo: 'Bs.',
          monto: '5000.00',
          plazoMeses: 12,
          destino: 'Electrodomésticos',
          canalOrigen: 'MOVIL',
          requiereEvaluacion: true,
        ),
      ];
      await store.saveWorklist(cachedWorklist);

      // Mock inner service that always throws network exception
      final offlineClient = MockClient((request) async {
        throw const SocketException('No route to host');
      });

      final syncCampoService = SyncCampoService(
        innerService: CampoService(),
        store: store,
      );

      final worklistResult = await syncCampoService.getWorklist(
        client: offlineClient,
      );

      expect(worklistResult.success, isTrue);
      expect(worklistResult.value?.length, 1);
      expect(worklistResult.value?.first.numeroSolicitud, 'SOL-55');
      expect(syncCampoService.isWorklistOffline, isTrue);
      expect(syncCampoService.lastWorklistCacheTime, testTime);
    });

    test('M11 Real Fixtures: Replay idempotency, 409 conflict, and 422 invalid UUID', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_fixtures_m11',
        now: mockClock,
      );

      // 1. Fixture: evaluacion_conflicto_409.json
      final conflict409File = File('test/fixtures/m11/evaluacion_conflicto_409.json');
      final conflict409Json = jsonDecode(conflict409File.readAsStringSync());
      expect(conflict409Json['status'], 409);
      expect(conflict409Json['body']['detail'], 'La solicitud ya no se puede modificar');

      // 2. Fixture: foto_subida_client_id.json (201) and foto_replay_client_id.json (200)
      final subida201File = File('test/fixtures/m11/foto_subida_client_id.json');
      final replay200File = File('test/fixtures/m11/foto_replay_client_id.json');
      final subidaJson = jsonDecode(subida201File.readAsStringSync());
      final replayJson = jsonDecode(replay200File.readAsStringSync());

      expect(subidaJson['status'], 201);
      expect(replayJson['status'], 200);
      expect(subidaJson['body'].length, 3);
      expect(replayJson['body'].length, 3);
      expect(subidaJson['body'][2]['id'], '1/3/13020e63-9d81-4ffa-a8f0-c6316b4a2b76.jpg');
      expect(replayJson['body'][2]['id'], equals(subidaJson['body'][2]['id']));

      // 3. Fixture: foto_client_id_invalido.json (422)
      final invalid422File = File('test/fixtures/m11/foto_client_id_invalido.json');
      final invalid422Json = jsonDecode(invalid422File.readAsStringSync());
      expect(invalid422Json['status'], 422);
      expect(invalid422Json['body']['detail'][0]['type'], 'uuid_parsing');

      // 4. Test photo upload with MockClient using real replay fixture
      final photoPath = await store.savePhotoBytes(
        '13020e63-9d81-4ffa-a8f0-c6316b4a2b76',
        [1, 2, 3],
        'foto.jpg',
      );

      final photoItem = QueueItem(
        id: 'photo-m11-item',
        kind: QueueItemKind.photoUpload,
        solicitudId: 3,
        createdAt: testTime,
        payload: {
          'client_id': '13020e63-9d81-4ffa-a8f0-c6316b4a2b76',
          'photo_file_path': photoPath,
          'filename': 'foto.jpg',
        },
      );
      await store.enqueue(photoItem);

      String? capturedHeader;
      final replayClient = MockClient((request) async {
        capturedHeader = request.headers['X-Client-Id'];
        return http.Response(
          jsonEncode(replayJson['body']),
          replayJson['status'] as int,
        );
      });

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      final syncRes = await syncService.sync(client: replayClient);
      expect(syncRes.syncedCount, 1);
      expect(capturedHeader, '13020e63-9d81-4ffa-a8f0-c6316b4a2b76');
      expect(await store.getQueue(), isEmpty);
    });

    test('Blocker 1: AuthService.currentUserId from JWT and OfflineStore user isolation', () async {
      // Craft a JWT token with sub="user_officer_99"
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
      final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': 'user_officer_99', 'rol': 'OFICIAL_CREDITO'})));
      final fakeJwt = '$header.$payload.fake_signature';

      // Setting token sets currentUserId
      AuthService.tokenJWT = fakeJwt;
      expect(AuthService.currentUserId, 'user_officer_99');

      // OfflineStore requires non-null user id; if null, OfflineStore.create returns null (online-only)
      AuthService.currentUserId = null;
      final nullStore = await OfflineStore.create(baseDirectory: tempDir);
      expect(nullStore, isNull);

      // OfflineStore throws assertion if empty user id is passed
      expect(
        () => OfflineStore(baseDirectory: tempDir, userId: ''),
        throwsA(isA<AssertionError>()),
      );

      // Two users are strictly isolated
      final storeA = OfflineStore(baseDirectory: tempDir, userId: 'officer_A', now: mockClock);
      final storeB = OfflineStore(baseDirectory: tempDir, userId: 'officer_B', now: mockClock);

      await storeA.enqueue(QueueItem(
        id: 'item-user-A',
        kind: QueueItemKind.evaluationSave,
        solicitudId: 10,
        createdAt: testTime,
        payload: const EvaluacionCampoForm(
          ingresoMensual: '1000.00',
          egresoMensual: '500.00',
          cuotaDeudasMensual: '0.00',
          actividadEconomica: 'A',
          fuenteIngresos: 'DEPENDIENTE',
          antiguedadLaboralMeses: 10,
          calificacionAsfi: 'A',
        ).toJson(),
      ));

      expect((await storeA.getQueue()).length, 1);
      expect((await storeB.getQueue()), isEmpty);
    });

    test('Blocker 2: Unlocked read-modify-write serialized via async mutex and atomic writes', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_concurrency',
        now: mockClock,
      );

      // 30 concurrent enqueues must preserve all 30 items
      final items = List.generate(
        30,
        (i) => QueueItem(
          id: 'item-$i',
          kind: QueueItemKind.evaluationSave,
          solicitudId: i,
          createdAt: testTime,
          payload: EvaluacionCampoForm(
            ingresoMensual: '${1000 + i}.00',
            egresoMensual: '500.00',
            cuotaDeudasMensual: '0.00',
            actividadEconomica: 'Test',
            fuenteIngresos: 'DEPENDIENTE',
            antiguedadLaboralMeses: 12,
            calificacionAsfi: 'A',
          ).toJson(),
        ),
      );

      await Future.wait(items.map((it) => store.enqueue(it)));
      final queueAfter30 = await store.getQueue();
      expect(queueAfter30.length, 30);

      // Interleaved remove and enqueue never resurrects
      await Future.wait([
        store.removeQueueItem('item-0'),
        store.removeQueueItem('item-1'),
        store.enqueue(QueueItem(
          id: 'item-31',
          kind: QueueItemKind.evaluationSave,
          solicitudId: 31,
          createdAt: testTime,
          payload: const EvaluacionCampoForm(
            ingresoMensual: '2000.00',
            egresoMensual: '500.00',
            cuotaDeudasMensual: '0.00',
            actividadEconomica: 'Test',
            fuenteIngresos: 'DEPENDIENTE',
            antiguedadLaboralMeses: 12,
            calificacionAsfi: 'A',
          ).toJson(),
        )),
      ]);

      final queueFinal = await store.getQueue();
      expect(queueFinal.length, 29);
      expect(queueFinal.any((i) => i.id == 'item-0'), isFalse);
      expect(queueFinal.any((i) => i.id == 'item-1'), isFalse);
      expect(queueFinal.any((i) => i.id == 'item-31'), isTrue);
    });

    test('Advisory 4: SyncService.sync() single-flight: concurrent calls share in-flight pass', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_single_flight',
        now: mockClock,
      );

      final deleteItem = QueueItem(
        id: 'delete-photo-item',
        kind: QueueItemKind.photoDelete,
        solicitudId: 50,
        createdAt: testTime,
        payload: {'foto_id': '50/photo.jpg'},
      );
      await store.enqueue(deleteItem);

      int deleteCalls = 0;
      final completer = Completer<void>();

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/fotos/50/photo.jpg')) {
          deleteCalls++;
          // Pause execution until second sync is initiated
          await completer.future;
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response('Not found', 404);
      });

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      // Launch sync pass 1
      final future1 = syncService.sync(client: mockClient);
      // Launch sync pass 2 concurrently
      final future2 = syncService.sync(client: mockClient);

      // Complete the network call
      completer.complete();

      final results = await Future.wait([future1, future2]);
      expect(results[0].syncedCount, 1);
      expect(results[1].syncedCount, 1);
      // Delete endpoint was called exactly once, no 404 conflict created
      expect(deleteCalls, 1);
      expect(await store.getConflicts(), isEmpty);
      expect(await store.getQueue(), isEmpty);
    });

    test('Advisory 5 / Follow-up 3: Corrupt/partial JSON moves file aside to .corrupt-<timestamp> and continues with empty queue', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_corrupt',
        now: mockClock,
      );

      // Create a corrupt queue.json
      final userDir = Directory('${tempDir.path}/offline_store/officer_corrupt');
      userDir.createSync(recursive: true);
      final queueFile = File('${userDir.path}/queue.json');
      await queueFile.writeAsString('{"malformed": [truncated json');

      // getQueue moves file aside and recovers with empty queue
      final queue = await store.getQueue();
      expect(queue, isEmpty);

      // Original queue.json no longer exists (moved aside)
      expect(queueFile.existsSync(), isFalse);

      // Corrupt file was created
      final corruptFiles = userDir
          .listSync()
          .where((f) => f.path.contains('queue.json.corrupt-'))
          .toList();
      expect(corruptFiles.length, 1);
    });

    test('Advisory 6: Malformed queue items are never dropped silently (routed to conflicts)', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_malformed',
        now: mockClock,
      );

      // Malformed items: missing solicitudId or missing payload
      final malformedEval = QueueItem(
        id: 'malformed-eval',
        kind: QueueItemKind.evaluationSave,
        solicitudId: null, // missing!
        createdAt: testTime,
        payload: {},
      );

      final malformedDelete = QueueItem(
        id: 'malformed-delete',
        kind: QueueItemKind.photoDelete,
        solicitudId: 10,
        createdAt: testTime,
        payload: {}, // missing foto_id!
      );

      await store.saveQueue([malformedEval, malformedDelete]);

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      final result = await syncService.sync();
      expect(result.conflictsCount, 2);
      expect(await store.getQueue(), isEmpty);

      final conflicts = await store.getConflicts();
      expect(conflicts.length, 2);
      expect(conflicts[0].statusCode, 422);
      expect(conflicts[0].error, contains('malformado'));
      expect(conflicts[1].statusCode, 422);
      expect(conflicts[1].error, contains('malformado'));
    });

    test('Advisory 7: Keep photo bytes on photo-upload conflict until discard', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_photo_keep',
        now: mockClock,
      );

      final photoPath = await store.savePhotoBytes(
        'photo-conflict-uuid',
        [4, 5, 6],
        'negocio.jpg',
      );
      expect(File(photoPath).existsSync(), isTrue);

      final photoItem = QueueItem(
        id: 'item-photo-conflict',
        kind: QueueItemKind.photoUpload,
        solicitudId: 88,
        createdAt: testTime,
        payload: {
          'client_id': 'photo-conflict-uuid',
          'photo_file_path': photoPath,
          'filename': 'negocio.jpg',
        },
      );
      await store.enqueue(photoItem);

      // MockClient returns 409 conflict
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'La solicitud ya no se puede modificar'}),
          409,
        );
      });

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      await syncService.sync(client: mockClient);

      // Item moved to conflicts
      final conflicts = await store.getConflicts();
      expect(conflicts.length, 1);
      expect(await store.getQueue(), isEmpty);

      // Photo file MUST STILL EXIST while conflict is pending
      expect(File(photoPath).existsSync(), isTrue);

      // Discarding conflict deletes the photo file
      await store.removeConflict(conflicts.first.id);
      expect(File(photoPath).existsSync(), isFalse);
    });

    test('Follow-up 1: R3-stale-eval-replay - Online eval save removes older queued eval for same solicitud', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_stale_online',
        now: mockClock,
      );

      const olderForm = EvaluacionCampoForm(
        ingresoMensual: '1000.00',
        egresoMensual: '500.00',
        cuotaDeudasMensual: '100.00',
        actividadEconomica: 'Comercio',
        fuenteIngresos: 'NEGOCIO_PROPIO',
        antiguedadLaboralMeses: 12,
        calificacionAsfi: 'A',
      );

      // Enqueue older evaluation for solicitud 10
      await store.enqueue(QueueItem(
        id: 'older-eval-10',
        kind: QueueItemKind.evaluationSave,
        solicitudId: 10,
        createdAt: testTime,
        payload: olderForm.toJson(),
      ));
      expect((await store.getQueue()).length, 1);

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/solicitudes/10') && request.method == 'PUT') {
          return http.Response(
            jsonEncode({
              'id': 10,
              'numero_solicitud': 'SOL-10',
              'fecha_solicitud': '2026-10-26',
              'estado': 'EVALUACION_CAMPO',
              'monto': '10000.00',
              'plazo_meses': 12,
              'destino': 'Capital de trabajo',
              'canal_origen': 'MOVIL',
              'requiere_evaluacion': false,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final syncCampoService = SyncCampoService(
        innerService: CampoService(),
        store: store,
      );

      const newerForm = EvaluacionCampoForm(
        ingresoMensual: '2500.00',
        egresoMensual: '800.00',
        cuotaDeudasMensual: '200.00',
        actividadEconomica: 'Comercio Mayorista',
        fuenteIngresos: 'NEGOCIO_PROPIO',
        antiguedadLaboralMeses: 24,
        calificacionAsfi: 'A',
      );

      final res = await syncCampoService.guardarEvaluacion(10, newerForm, client: mockClient);
      expect(res.success, isTrue);

      // Older queued eval for solicitud 10 must be gone
      final queueAfter = await store.getQueue();
      expect(
        queueAfter.where((i) => i.kind == QueueItemKind.evaluationSave && i.solicitudId == 10),
        isEmpty,
      );
    });

    test('Follow-up 1: R3-stale-eval-replay - Offline eval enqueue replaces existing queued eval keeping FIFO position', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_stale_replace',
        now: mockClock,
      );

      final inner = MockClient((request) async {
        throw const SocketException('No internet');
      });

      final syncCampoService = SyncCampoService(
        innerService: CampoService(),
        store: store,
      );

      // 1. Enqueue eval for solicitud 10
      const formV1 = EvaluacionCampoForm(
        ingresoMensual: '1000.00',
        egresoMensual: '500.00',
        cuotaDeudasMensual: '0.00',
        actividadEconomica: 'Artesanía',
        fuenteIngresos: 'INDEPENDIENTE',
        antiguedadLaboralMeses: 6,
        calificacionAsfi: 'A',
      );
      await syncCampoService.guardarEvaluacion(10, formV1, client: inner);

      // 2. Enqueue photo for solicitud 20
      final photoPath = await store.savePhotoBytes('client-uuid-20', [1, 2, 3], 'negocio.jpg');
      await store.enqueue(QueueItem(
        id: 'photo-20',
        kind: QueueItemKind.photoUpload,
        solicitudId: 20,
        createdAt: testTime,
        payload: {
          'client_id': 'client-uuid-20',
          'photo_file_path': photoPath,
          'filename': 'negocio.jpg',
        },
      ));

      expect((await store.getQueue()).length, 2);

      // 3. Enqueue updated eval for solicitud 10 while offline
      const formV2 = EvaluacionCampoForm(
        ingresoMensual: '3000.00',
        egresoMensual: '1200.00',
        cuotaDeudasMensual: '100.00',
        actividadEconomica: 'Artesanía Fina',
        fuenteIngresos: 'INDEPENDIENTE',
        antiguedadLaboralMeses: 18,
        calificacionAsfi: 'A',
      );
      await syncCampoService.guardarEvaluacion(10, formV2, client: inner);

      // Queue length must still be 2 (replaced, not duplicated)
      final queue = await store.getQueue();
      expect(queue.length, 2);

      // Position 0 must still be solicitud 10, but with updated formV2 content
      expect(queue[0].kind, QueueItemKind.evaluationSave);
      expect(queue[0].solicitudId, 10);
      expect(queue[0].evaluacionForm?.ingresoMensual, '3000.00');
      expect(queue[0].evaluacionForm?.actividadEconomica, 'Artesanía Fina');

      // Position 1 must still be photo-20
      expect(queue[1].id, 'photo-20');
      expect(queue[1].solicitudId, 20);
    });

    test('Follow-up 3: R3-corrupt-queue-loss - Corrupt file is moved aside, empty queue continues, enqueue succeeds and flags notice', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_corrupt_recovery',
        now: mockClock,
      );

      final userDir = Directory('${tempDir.path}/offline_store/officer_corrupt_recovery');
      userDir.createSync(recursive: true);
      final queueFile = File('${userDir.path}/queue.json');
      await queueFile.writeAsString('{"corrupted_data": [unclosed');

      final newItem = QueueItem(
        id: 'new-valid-item',
        kind: QueueItemKind.photoDelete,
        solicitudId: 5,
        createdAt: testTime,
        payload: {'foto_id': '5/foto.jpg'},
      );

      // Enqueue must succeed instead of throwing FormatException
      await store.enqueue(newItem);

      // Queue contains the newly enqueued item
      final queue = await store.getQueue();
      expect(queue.length, 1);
      expect(queue.first.id, 'new-valid-item');

      // Backup file exists
      final corruptBackups = userDir.listSync().where((f) => f.path.contains('queue.json.corrupt-')).toList();
      expect(corruptBackups.length, 1);

      // Persistent corrupt notice flag exists
      expect(await store.hasCorruptNotice(), isTrue);
    });

    test('Follow-up 4: R3-malformed-eval-defaults - evaluacionForm returns null when required fields missing and routes to conflict', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_malformed_eval',
        now: mockClock,
      );

      // Missing required fields (e.g. no actividad_economica, no calificacion_asfi)
      final incompleteItem = QueueItem(
        id: 'incomplete-eval-item',
        kind: QueueItemKind.evaluationSave,
        solicitudId: 15,
        createdAt: testTime,
        payload: {
          'ingreso_mensual': '1500.00',
          // missing egreso_mensual, actividad_economica, fuente_ingresos, antiguedad_laboral_meses, calificacion_asfi
        },
      );

      expect(incompleteItem.evaluacionForm, isNull);

      await store.enqueue(incompleteItem);

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      final result = await syncService.sync();
      expect(result.conflictsCount, 1);
      expect(await store.getQueue(), isEmpty);

      final conflicts = await store.getConflicts();
      expect(conflicts.length, 1);
      expect(conflicts.first.statusCode, 422);
      expect(conflicts.first.error, contains('malformado'));
    });

    test('Follow-up 5: R4-5xx-retry-forever - 5xx increments attemptCount, moves to conflict after 5, and doesn\'t block unrelated solicitudes', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_5xx_retry',
        now: mockClock,
      );

      const validForm = EvaluacionCampoForm(
        ingresoMensual: '2000.00',
        egresoMensual: '1000.00',
        cuotaDeudasMensual: '0.00',
        actividadEconomica: 'Comercio',
        fuenteIngresos: 'INDEPENDIENTE',
        antiguedadLaboralMeses: 12,
        calificacionAsfi: 'A',
      );

      final item10 = QueueItem(
        id: 'eval-10',
        kind: QueueItemKind.evaluationSave,
        solicitudId: 10,
        createdAt: testTime,
        payload: validForm.toJson(),
      );

      final item20 = QueueItem(
        id: 'eval-20',
        kind: QueueItemKind.evaluationSave,
        solicitudId: 20,
        createdAt: testTime,
        payload: validForm.toJson(),
      );

      await store.saveQueue([item10, item20]);

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/solicitudes/10')) {
          return http.Response(jsonEncode({'detail': 'Internal Server Error'}), 500);
        }
        if (request.url.path.contains('/solicitudes/20')) {
          return http.Response(
            jsonEncode({
              'id': 20,
              'numero_solicitud': 'SOL-20',
              'fecha_solicitud': '2026-10-26',
              'estado': 'EVALUACION_CAMPO',
              'monto': '12000.00',
              'plazo_meses': 12,
              'destino': 'Comercio',
              'canal_origen': 'MOVIL',
              'requiere_evaluacion': false,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      // Attempt 1: solicitud 20 succeeds, solicitud 10 increments attemptCount
      final res1 = await syncService.sync(client: mockClient);
      expect(res1.syncedCount, 1); // Solicitud 20 was NOT blocked!
      var queue = await store.getQueue();
      expect(queue.length, 1);
      expect(queue.first.solicitudId, 10);
      expect(queue.first.attemptCount, 1);

      // Attempts 2, 3, 4:
      for (int i = 2; i <= 4; i++) {
        await syncService.sync(client: mockClient);
        queue = await store.getQueue();
        expect(queue.length, 1);
        expect(queue.first.attemptCount, i);
      }

      // Attempt 5: fails over to conflicts!
      await syncService.sync(client: mockClient);
      expect(await store.getQueue(), isEmpty);
      final conflicts = await store.getConflicts();
      expect(conflicts.length, 1);
      expect(conflicts.first.statusCode, 500);
      expect(conflicts.first.item.attemptCount, 5);
      expect(conflicts.first.error, contains('Internal Server Error'));
    });

    test('Follow-up 5: R4-5xx-retry-forever - 400 validation error goes straight to conflicts without retry', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_400_direct',
        now: mockClock,
      );

      const form = EvaluacionCampoForm(
        ingresoMensual: '2000.00',
        egresoMensual: '1000.00',
        cuotaDeudasMensual: '0.00',
        actividadEconomica: 'Comercio',
        fuenteIngresos: 'INDEPENDIENTE',
        antiguedadLaboralMeses: 12,
        calificacionAsfi: 'A',
      );

      await store.enqueue(QueueItem(
        id: 'eval-400',
        kind: QueueItemKind.evaluationSave,
        solicitudId: 30,
        createdAt: testTime,
        payload: form.toJson(),
      ));

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Monto excede límite'}), 400);
      });

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      await syncService.sync(client: mockClient);
      expect(await store.getQueue(), isEmpty);
      final conflicts = await store.getConflicts();
      expect(conflicts.length, 1);
      expect(conflicts.first.statusCode, 400);
      expect(conflicts.first.error, contains('Monto excede límite'));
    });

    test('Follow-up 6: R3-network-classification - HandshakeException, HttpException, TlsException are network errors', () async {
      final service = CampoService();

      // HandshakeException
      final clientHandshake = MockClient((request) async {
        throw const HandshakeException('Handshake failure');
      });
      final resHandshake = await service.getWorklist(client: clientHandshake);
      expect(resHandshake.success, isFalse);
      expect(resHandshake.isNetworkError, isTrue);

      // HttpException
      final clientHttp = MockClient((request) async {
        throw const HttpException('Connection closed');
      });
      final resHttp = await service.getWorklist(client: clientHttp);
      expect(resHttp.success, isFalse);
      expect(resHttp.isNetworkError, isTrue);

      // TlsException
      final clientTls = MockClient((request) async {
        throw const TlsException('TLS error');
      });
      final resTls = await service.getWorklist(client: clientTls);
      expect(resTls.success, isFalse);
      expect(resTls.isNetworkError, isTrue);
    });

    test('Follow-up 6: R1-raw-exception-text-ui - Generic Spanish message on unexpected exception without raw string', () async {
      final service = CampoService();

      final clientBug = MockClient((request) async {
        throw StateError('CRITICAL_INTERNAL_DB_PASSWORD_XYZ');
      });

      final res = await service.getWorklist(client: clientBug);
      expect(res.success, isFalse);
      expect(res.isNetworkError, isFalse);
      expect(res.error, 'Ocurrió un error inesperado. Intente nuevamente.');
      expect(res.error, isNot(contains('CRITICAL_INTERNAL_DB_PASSWORD_XYZ')));
    });

    test('Follow-up 7: R4-precal-replay-duplicate - Precal queue items have client UUID and dedupe completed list on replay', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_precal_dedupe',
        now: mockClock,
      );

      const form = PrecalificacionForm(
        socioId: 1,
        productoId: 2,
        monto: '5000.00',
        plazoMeses: 12,
        ingresoMensual: '3000.00',
        egresoMensual: '1000.00',
        cuotaDeudasMensual: '0.00',
        antiguedadLaboralMeses: 24,
      );

      final innerClient = MockClient((request) async {
        throw const SocketException('offline');
      });

      final syncCampoService = SyncCampoService(
        innerService: CampoService(),
        store: store,
      );

      // Enqueue offline: must have client_id
      await syncCampoService.precalificar(form, client: innerClient);
      final queue = await store.getQueue();
      expect(queue.length, 1);
      final clientId = queue.first.clientId;
      expect(clientId, isNotNull);
      expect(clientId!.isNotEmpty, isTrue);

      final serverClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'precalificacion': true,
            'score': 850,
            'dictamen': 'APROBADO',
            'factores': [],
            'knockouts': [],
            'socio': {'id': 1, 'nombre_completo': 'Ana Maria', 'ci': '1122334'},
            'producto': {'id': 2, 'nombre': 'Microcrédito'},
          }),
          200,
        );
      });

      final syncService = SyncService(
        campoService: CampoService(),
        store: store,
      );

      // Pass 1: synced and saved
      await syncService.sync(client: serverClient);
      var completed = await store.getCompletedPrequalifications();
      expect(completed.length, 1);
      expect(completed.first.clientId, clientId);

      // Replay / re-save with same clientId does NOT create a duplicate
      await store.saveCompletedPrequalification(completed.first);
      completed = await store.getCompletedPrequalifications();
      expect(completed.length, 1);
    });

    test('Follow-up 8: R3-worklist-cache-filter - Cache per canal filter key and offline mode respects filter', () async {
      final store = OfflineStore(
        baseDirectory: tempDir,
        userId: 'officer_cache_filter',
        now: mockClock,
      );

      final innerClient = MockClient((request) async {
        final canal = request.url.queryParameters['canal_origen'];
        if (canal == 'MOVIL') {
          return http.Response(
            jsonEncode([
              {
                'id': 101,
                'numero_solicitud': 'SOL-101',
                'fecha_solicitud': '2026-10-26',
                'estado': 'PENDIENTE_EVALUACION',
                'socio': {'id': 1, 'nombre': 'Mario', 'apellido': 'Gomez', 'ci': '123'},
                'producto': {'id': 1, 'nombre': 'Microcrédito'},
                'monto': '5000.00',
                'plazo_meses': 12,
                'destino': 'Comercio',
                'canal_origen': 'MOVIL',
                'requiere_evaluacion': true,
              }
            ]),
            200,
          );
        }
        return http.Response(jsonEncode([]), 200);
      });

      final syncCampoService = SyncCampoService(
        innerService: CampoService(),
        store: store,
      );

      // 1. Fetch MOVIL online -> cached under MOVIL
      final resOnline = await syncCampoService.getWorklist(
        canalOrigen: 'MOVIL',
        client: innerClient,
      );
      expect(resOnline.success, isTrue);
      expect(resOnline.value?.length, 1);

      // 2. Offline: Fetch MOVIL -> returns cached MOVIL
      final offlineClient = MockClient((request) async {
        throw const SocketException('No network');
      });

      final resOfflineMovil = await syncCampoService.getWorklist(
        canalOrigen: 'MOVIL',
        client: offlineClient,
      );
      expect(resOfflineMovil.success, isTrue);
      expect(resOfflineMovil.value?.length, 1);
      expect(resOfflineMovil.value?.first.id, 101);

      // 3. Offline: Fetch VENTANILLA -> no cache for VENTANILLA, returns explicit message
      final resOfflineVentanilla = await syncCampoService.getWorklist(
        canalOrigen: 'VENTANILLA',
        client: offlineClient,
      );
      expect(resOfflineVentanilla.success, isFalse);
      expect(resOfflineVentanilla.error, contains('No hay datos guardados para este filtro'));
    });
  });
}
