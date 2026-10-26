import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/campo_model.dart';
import 'package:forest_microfinance/models/sync_model.dart';
import 'package:forest_microfinance/screens/campo_screens.dart';
import 'package:forest_microfinance/screens/conflictos_screen.dart';
import 'package:forest_microfinance/services/campo_service.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/offline_store.dart';
import 'package:forest_microfinance/services/sync_campo_service.dart';
import 'package:forest_microfinance/services/sync_service.dart';
import 'package:forest_microfinance/widgets/offline_banner.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(
      home: child,
    ),
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class FakeOfflineCampoService extends CampoService {
  List<SolicitudResumenCampo> worklist = [
    const SolicitudResumenCampo(
      id: 42,
      numeroSolicitud: 'SOL-042',
      fechaSolicitud: '2026-10-26',
      estado: 'PENDIENTE_EVALUACION',
      socioNombre: 'Carlos Morales',
      socioCi: '4567890',
      productoNombre: 'Microcrédito',
      monedaSimbolo: 'Bs.',
      monto: '12000.00',
      plazoMeses: 12,
      destino: 'Comercio',
      canalOrigen: 'MOVIL',
      requiereEvaluacion: true,
    ),
  ];

  FichaCampo ficha = const FichaCampo(
    solicitud: FichaCampoSolicitud(
      id: 42,
      numeroSolicitud: 'SOL-042',
      estado: 'PENDIENTE_EVALUACION',
      monto: '12000.00',
      plazoMeses: 12,
      destino: 'Comercio',
      canalOrigen: 'MOVIL',
      producto: 'Microcrédito',
      requiereEvaluacion: true,
    ),
    socio: FichaCampoSocio(
      id: 7,
      nombreCompleto: 'Carlos Morales',
      ci: '4567890',
    ),
    catalogos: CatalogosFichaCampo(
      fuentesIngresos: ['DEPENDIENTE', 'INDEPENDIENTE'],
      calificacionesAsfi: ['A', 'B'],
    ),
  );

  bool simulateNetworkError = false;

  @override
  Future<CampoResult<List<SolicitudResumenCampo>>> getWorklist({
    bool requiereEvaluacion = true,
    String? canalOrigen,
    http.Client? client,
  }) async {
    if (simulateNetworkError) {
      return const CampoResult.networkError('Error de conexión');
    }
    return CampoResult.success(worklist);
  }

  @override
  Future<CampoResult<FichaCampo>> getFichaCampo(
    int solicitudId, {
    http.Client? client,
  }) async {
    if (simulateNetworkError) {
      return const CampoResult.networkError('Error de conexión');
    }
    return CampoResult.success(ficha);
  }

  @override
  Future<CampoResult<List<SocioPrecalificacion>>> getSociosActivos({
    http.Client? client,
  }) async {
    if (simulateNetworkError) {
      return const CampoResult.networkError('Error de conexión');
    }
    return const CampoResult.success([
      SocioPrecalificacion(id: 7, ci: '4567890', nombre: 'Carlos', apellido: 'Morales'),
    ]);
  }

  @override
  Future<CampoResult<List<ProductoPrecalificacion>>> getProductosActivos({
    http.Client? client,
  }) async {
    if (simulateNetworkError) {
      return const CampoResult.networkError('Error de conexión');
    }
    return const CampoResult.success([
      ProductoPrecalificacion(
        id: 1,
        codigo: 'MICRO',
        nombre: 'Microcrédito',
        monedaSimbolo: 'Bs.',
        montoMin: '1000.00',
        montoMax: '50000.00',
        plazoMinMeses: 6,
        plazoMaxMeses: 36,
        tasaInteresAnual: '18.00',
        requiereGarantia: false,
      ),
    ]);
  }

  @override
  Future<CampoResult<SolicitudResumenCampo>> guardarEvaluacion(
    int solicitudId,
    EvaluacionCampoForm form, {
    http.Client? client,
  }) async {
    if (simulateNetworkError) {
      return const CampoResult.networkError('Error de conexión');
    }
    return CampoResult.success(worklist.first);
  }

  @override
  Future<CampoResult<List<FotoEvaluacionCampo>>> subirFotoEvaluacion(
    int solicitudId, {
    required List<int> bytes,
    required String filename,
    String? clientId,
    http.Client? client,
  }) async {
    if (simulateNetworkError) {
      return const CampoResult.networkError('Error de conexión');
    }
    return const CampoResult.success([]);
  }

  @override
  Future<CampoResult<List<FotoEvaluacionCampo>>> eliminarFotoEvaluacion(
    int solicitudId,
    String fotoId, {
    http.Client? client,
  }) async {
    if (simulateNetworkError) {
      return const CampoResult.networkError('Error de conexión');
    }
    return const CampoResult.success([]);
  }

  @override
  Future<CampoResult<PrecalificacionResultado>> precalificar(
    PrecalificacionForm form, {
    http.Client? client,
  }) async {
    if (simulateNetworkError) {
      return const CampoResult.networkError('Error de conexión');
    }
    return const CampoResult.success(
      PrecalificacionResultado(
        precalificacion: true,
        score: 800,
        dictamen: 'APROBADO',
        socioNombre: 'Carlos Morales',
        productoNombre: 'Microcrédito',
        cuotaEstimada: '950.00',
        probabilidadMora: '0.02',
        nivelRiesgo: 'BAJO',
        factores: [],
        knockouts: [],
      ),
    );
  }
}

class _OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw const SocketException('Network unreachable');
  }
}

class InMemoryOfflineStore extends OfflineStore {
  final Map<String, dynamic> _storage = {};
  final List<QueueItem> _queue = [];
  final List<SyncConflict> _conflicts = [];

  InMemoryOfflineStore({
    required super.userId,
    super.now,
  }) : super(baseDirectory: Directory.systemTemp);

  @override
  Future<void> saveWorklist(
    List<SolicitudResumenCampo> items, {
    String filterKey = 'TODOS',
  }) async {
    final key = filterKey.toUpperCase();
    _storage['worklist_$key'] = CachedData(data: items, timestamp: now());
    if (key == 'TODOS') {
      _storage['worklist'] = CachedData(data: items, timestamp: now());
    }
  }

  @override
  Future<CachedData<List<SolicitudResumenCampo>>?> getWorklist({
    String filterKey = 'TODOS',
  }) async {
    final key = filterKey.toUpperCase();
    return (_storage['worklist_$key'] ??
            (key == 'TODOS' ? _storage['worklist'] : null))
        as CachedData<List<SolicitudResumenCampo>>?;
  }

  @override
  Future<void> saveFicha(int solicitudId, FichaCampo ficha) async {
    _storage['ficha_$solicitudId'] = CachedData(data: ficha, timestamp: now());
  }

  @override
  Future<CachedData<FichaCampo>?> getFicha(int solicitudId) async {
    return _storage['ficha_$solicitudId'] as CachedData<FichaCampo>?;
  }

  @override
  Future<void> saveSocios(List<SocioPrecalificacion> socios) async {
    _storage['socios'] = CachedData(data: socios, timestamp: now());
  }

  @override
  Future<CachedData<List<SocioPrecalificacion>>?> getSocios() async {
    return _storage['socios'] as CachedData<List<SocioPrecalificacion>>?;
  }

  @override
  Future<void> saveProductos(List<ProductoPrecalificacion> productos) async {
    _storage['productos'] = CachedData(data: productos, timestamp: now());
  }

  @override
  Future<CachedData<List<ProductoPrecalificacion>>?> getProductos() async {
    return _storage['productos'] as CachedData<List<ProductoPrecalificacion>>?;
  }

  @override
  Future<List<QueueItem>> getQueue() async => List.from(_queue);

  @override
  Future<void> saveQueue(List<QueueItem> items) async {
    _queue.clear();
    _queue.addAll(items);
  }

  @override
  Future<void> enqueue(QueueItem item) async {
    _queue.add(item);
  }

  @override
  Future<void> removeQueueItem(String itemId) async {
    _queue.removeWhere((i) => i.id == itemId);
  }

  @override
  Future<void> clearQueue() async {
    _queue.clear();
  }

  @override
  Future<List<SyncConflict>> getConflicts() async => List.from(_conflicts);

  @override
  Future<void> saveConflicts(List<SyncConflict> conflicts) async {
    _conflicts.clear();
    _conflicts.addAll(conflicts);
  }

  @override
  Future<void> addConflict(SyncConflict conflict) async {
    _conflicts.add(conflict);
  }

  @override
  Future<void> removeConflict(String conflictId) async {
    _conflicts.removeWhere((c) => c.id == conflictId);
  }

  @override
  Future<void> clearConflicts() async {
    _conflicts.clear();
  }

  final List<PrecalificacionResultado> _completedPrequalifications = [];

  @override
  Future<List<PrecalificacionResultado>> getCompletedPrequalifications() async =>
      List.from(_completedPrequalifications);

  @override
  Future<void> saveCompletedPrequalification(
    PrecalificacionResultado result,
  ) async {
    _completedPrequalifications.add(result);
  }

  bool simulatedCorruptNotice = false;

  @override
  Future<bool> hasCorruptNotice() async => simulatedCorruptNotice;

  @override
  Future<void> clearCorruptNotice() async {
    simulatedCorruptNotice = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 10, 26, 9, 30);

  setUp(() {
    AuthService.tokenJWT = 'test-token';
  });

  tearDown(() {
    AuthService.tokenJWT = null;
  });

  group('CU-M11 Offline Sync Widget Tests', () {
    testWidgets('OfflineBanner displays formatted date and message',
        (tester) async {
      await tester.pumpWidget(
        _wrap(OfflineBanner(cachedTimestamp: testDate)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(
        find.textContaining('Sin conexión — datos guardados el 26/10/2026 09:30'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets(
        'CampoHomeScreen shows OfflineBanner and pending sync markers when offline',
        (tester) async {
      _setLargeSurface(tester);

      final store = InMemoryOfflineStore(
        userId: 'officer_widgets',
        now: () => testDate,
      );

      final inner = FakeOfflineCampoService();
      // Preload store cache
      await store.saveWorklist(inner.worklist);

      // Enqueue an evaluation save for request 42
      final item = QueueItem(
        id: 'queued-42',
        kind: QueueItemKind.evaluationSave,
        solicitudId: 42,
        createdAt: testDate,
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
      await store.enqueue(item);

      // Now simulate offline network error
      inner.simulateNetworkError = true;

      final syncCampoService = SyncCampoService(
        innerService: inner,
        store: store,
      );

      await tester.pumpWidget(
        _wrap(
          CampoHomeScreen(
            service: syncCampoService,
            store: store,
          ),
        ),
      );
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Offline banner should be visible
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(
        find.textContaining('Sin conexión — datos guardados el 26/10/2026 09:30'),
        findsOneWidget,
      );

      // Queued item badge should appear in the worklist item
      expect(find.byKey(const Key('solicitud_pendiente_sync_badge_42')), findsOneWidget);
      expect(find.text('Pendiente de sincronizar'), findsWidgets);

      // Sync button badge should show count 1
      expect(find.byKey(const Key('campo_sync_btn')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets(
        'FichaCampoScreen shows OfflineBanner and pending sync badge',
        (tester) async {
      _setLargeSurface(tester);

      final store = InMemoryOfflineStore(
        userId: 'officer_widgets_ficha',
        now: () => testDate,
      );

      final inner = FakeOfflineCampoService();
      await store.saveFicha(42, inner.ficha);

      final item = QueueItem(
        id: 'queued-ficha-42',
        kind: QueueItemKind.evaluationSave,
        solicitudId: 42,
        createdAt: testDate,
        payload: const EvaluacionCampoForm(
          ingresoMensual: '6000.00',
          egresoMensual: '2500.00',
          cuotaDeudasMensual: '0.00',
          actividadEconomica: 'Comercio',
          fuenteIngresos: 'INDEPENDIENTE',
          antiguedadLaboralMeses: 24,
          calificacionAsfi: 'A',
        ).toJson(),
      );
      await store.enqueue(item);

      inner.simulateNetworkError = true;

      final syncCampoService = SyncCampoService(
        innerService: inner,
        store: store,
      );

      await tester.pumpWidget(
        _wrap(
          FichaCampoScreen(
            solicitudId: 42,
            service: syncCampoService,
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // OfflineBanner should be shown
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(
        find.textContaining('Sin conexión — datos guardados el 26/10/2026 09:30'),
        findsOneWidget,
      );

      // Ficha pending sync badge should be present
      expect(find.byKey(const Key('ficha_pendiente_sync_badge')), findsOneWidget);
      expect(find.text('Pendiente de sincronizar'), findsOneWidget);
    });

    testWidgets(
        'PrecalificacionScreen shows OfflineBanner and enqueues on network error',
        (tester) async {
      _setLargeSurface(tester);

      final store = InMemoryOfflineStore(
        userId: 'officer_widgets_precal',
        now: () => testDate,
      );

      final inner = FakeOfflineCampoService();
      // Cache socios and productos
      await store.saveSocios(const [
        SocioPrecalificacion(id: 7, ci: '4567890', nombre: 'Carlos', apellido: 'Morales'),
      ]);
      await store.saveProductos(const [
        ProductoPrecalificacion(
          id: 1,
          codigo: 'MICRO',
          nombre: 'Microcrédito',
          monedaSimbolo: 'Bs.',
          montoMin: '1000.00',
          montoMax: '50000.00',
          plazoMinMeses: 6,
          plazoMaxMeses: 36,
          tasaInteresAnual: '18.00',
          requiereGarantia: false,
        ),
      ]);

      inner.simulateNetworkError = true;

      final syncCampoService = SyncCampoService(
        innerService: inner,
        store: store,
      );

      await tester.pumpWidget(
        _wrap(
          PrecalificacionScreen(
            service: syncCampoService,
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Offline banner shown
      expect(find.byType(OfflineBanner), findsOneWidget);

      // Select socio
      await tester.tap(find.byKey(const Key('precal_seleccionar_socio_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('precal_socio_tile_7')));
      await tester.pumpAndSettle();

      // Fill valid form fields
      await tester.enterText(find.byKey(const Key('precal_monto_field')), '10000');
      await tester.enterText(find.byKey(const Key('precal_plazo_field')), '12');
      await tester.enterText(find.byKey(const Key('precal_ingreso_field')), '5000');
      await tester.enterText(find.byKey(const Key('precal_egreso_field')), '2000');
      await tester.enterText(find.byKey(const Key('precal_antiguedad_field')), '24');
      await tester.pumpAndSettle();

      // Tap Precalificar while offline
      await tester.tap(find.byKey(const Key('precal_calcular_btn')));
      await tester.pumpAndSettle();

      // Verify SnackBar popped and item was queued
      expect(
        find.text('Sin conexión. Precalificación en cola (Pendiente de sincronizar).'),
        findsOneWidget,
      );

      final queue = await store.getQueue();
      expect(queue.length, 1);
      expect(queue.first.kind, QueueItemKind.prequalification);
    });

    testWidgets('ConflictosScreen renders conflict items and allows discarding',
        (tester) async {
      _setLargeSurface(tester);

      final store = InMemoryOfflineStore(
        userId: 'officer_widgets_conflicts',
        now: () => testDate,
      );

      final conflict1 = SyncConflict(
        id: 'conflict-1',
        item: QueueItem(
          id: 'item-eval-1',
          kind: QueueItemKind.evaluationSave,
          solicitudId: 66,
          createdAt: testDate,
          payload: {'ingreso_mensual': '5000.00'},
        ),
        error: 'La solicitud ya no se puede modificar',
        statusCode: 409,
        timestamp: testDate,
      );

      final conflict2 = SyncConflict(
        id: 'conflict-2',
        item: QueueItem(
          id: 'item-photo-2',
          kind: QueueItemKind.photoUpload,
          solicitudId: 77,
          createdAt: testDate,
          payload: {'filename': 'negocio.jpg'},
        ),
        error: 'Input should be a valid UUID',
        statusCode: 422,
        timestamp: testDate,
      );

      await store.saveConflicts([conflict1, conflict2]);

      await tester.pumpWidget(
        _wrap(
          ConflictosScreen(
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify both conflicts are displayed with their server detail
      expect(find.textContaining('La solicitud ya no se puede modificar'), findsOneWidget);
      expect(find.textContaining('Input should be a valid UUID'), findsOneWidget);
      expect(find.text('Error 409'), findsOneWidget);
      expect(find.text('Error 422'), findsOneWidget);

      // Discard single conflict
      final discardSingleBtn = find.byKey(const Key('conflicto_descartar_btn_conflict-1'));
      expect(discardSingleBtn, findsOneWidget);
      await tester.tap(discardSingleBtn);
      await tester.pumpAndSettle();

      expect(find.text('Conflicto descartado.'), findsOneWidget);

      // Only conflict2 remains
      expect(find.textContaining('La solicitud ya no se puede modificar'), findsNothing);
      expect(find.textContaining('Input should be a valid UUID'), findsOneWidget);
      expect((await store.getConflicts()).length, 1);

      // Discard all conflicts
      final discardAllBtn = find.byKey(const Key('descartar_todos_conflictos_btn'));
      await tester.tap(discardAllBtn);
      await tester.pumpAndSettle();

      expect(find.text('Descartar todos los conflictos'), findsOneWidget);
      await tester.tap(find.text('Descartar todos'));
      await tester.pumpAndSettle();

      // Empty state
      expect(find.text('No hay conflictos de sincronización.'), findsOneWidget);
      expect(await store.getConflicts(), isEmpty);
    });

    testWidgets(
        'Blocker 3: CampoHomeScreen without injected service awaits storeFactory before first load offline',
        (tester) async {
      _setLargeSurface(tester);
      HttpOverrides.global = _OfflineHttpOverrides();
      addTearDown(() => HttpOverrides.global = null);

      final store = InMemoryOfflineStore(
        userId: 'officer_factory_test',
        now: () => testDate,
      );

      const cachedWorklist = [
        SolicitudResumenCampo(
          id: 99,
          numeroSolicitud: 'SOL-099',
          fechaSolicitud: '2026-10-26',
          estado: 'PENDIENTE_EVALUACION',
          socioNombre: 'Elena Rios',
          socioCi: '8877665',
          productoNombre: 'Microcrédito',
          monedaSimbolo: 'Bs.',
          monto: '15000.00',
          plazoMeses: 24,
          destino: 'Comercio',
          canalOrigen: 'MOVIL',
          requiereEvaluacion: true,
        ),
      ];
      await store.saveWorklist(cachedWorklist);

      // Build CampoHomeScreen WITHOUT an injected service, but with storeFactory, while offline
      // Mock AuthService.tokenJWT with non-null user id
      AuthService.currentUserId = 'officer_factory_test';

      await tester.pumpWidget(
        _wrap(
          CampoHomeScreen(
            storeFactory: () async => store,
          ),
        ),
      );
      // Wait for store initialization and first load
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Offline banner is shown and cached item SOL-099 is visible
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.text('SOL-099'), findsOneWidget);
      expect(find.text('Elena Rios (CI: 8877665)'), findsOneWidget);
    });

    testWidgets(
        'Advisory 9: CampoHomeScreen has visible "Sincronizar ahora" label and PrecalificacionScreen shows completed prequalifications',
        (tester) async {
      _setLargeSurface(tester);

      final store = InMemoryOfflineStore(
        userId: 'officer_advisory_9',
        now: () => testDate,
      );

      const completedPrecal = PrecalificacionResultado(
        precalificacion: true,
        score: 875,
        dictamen: 'APROBADO',
        socioNombre: 'Lucia Mendoza',
        productoNombre: 'Microcrédito',
        cuotaEstimada: '1200.00',
        probabilidadMora: '0.01',
        nivelRiesgo: 'BAJO',
        factores: [],
        knockouts: [],
      );
      await store.saveCompletedPrequalification(completedPrecal);

      final inner = FakeOfflineCampoService();
      await store.saveWorklist(inner.worklist);
      await store.saveSocios(const [
        SocioPrecalificacion(id: 7, ci: '4567890', nombre: 'Carlos', apellido: 'Morales'),
      ]);
      await store.saveProductos(const [
        ProductoPrecalificacion(
          id: 1,
          codigo: 'MICRO',
          nombre: 'Microcrédito',
          monedaSimbolo: 'Bs.',
          montoMin: '1000.00',
          montoMax: '50000.00',
          plazoMinMeses: 6,
          plazoMaxMeses: 36,
          tasaInteresAnual: '18.00',
          requiereGarantia: false,
        ),
      ]);

      final syncCampoService = SyncCampoService(
        innerService: inner,
        store: store,
      );

      // Verify CampoHomeScreen visible 'Sincronizar ahora' label
      await tester.pumpWidget(
        _wrap(
          CampoHomeScreen(
            service: syncCampoService,
            store: store,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sincronizar ahora'), findsOneWidget);

      // Verify PrecalificacionScreen displays completed prequalifications
      await tester.pumpWidget(
        _wrap(
          PrecalificacionScreen(
            service: syncCampoService,
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Completed prequalification section / item is displayed
      expect(find.text('Precalificaciones completadas'), findsOneWidget);
      expect(find.text('Lucia Mendoza'), findsOneWidget);
      expect(find.text('APROBADO (875 pts)'), findsOneWidget);
    });

    testWidgets(
        'Follow-up 2: Manual sync exception resets _syncing, shows Spanish error, and leaves button enabled',
        (tester) async {
      _setLargeSurface(tester);

      final store = InMemoryOfflineStore(
        userId: 'officer_failing_sync',
        now: () => testDate,
      );

      final inner = FakeOfflineCampoService();
      await store.saveWorklist(inner.worklist);

      final failingSyncService = _FailingSyncService(
        campoService: inner,
        store: store,
      );

      await tester.pumpWidget(
        _wrap(
          CampoHomeScreen(
            service: inner,
            store: store,
            syncService: failingSyncService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap sync button
      await tester.tap(find.byKey(const Key('campo_sync_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Error message shown in SnackBar
      expect(find.textContaining('Error durante la sincronización'), findsOneWidget);

      // Button is still present, enabled, and not stuck with spinner
      final syncBtn = tester.widget<TextButton>(find.byKey(const Key('campo_sync_btn')));
      expect(syncBtn.onPressed, isNotNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
        'Follow-up 3: CampoHomeScreen displays persistent notice when corrupt sync file was detected',
        (tester) async {
      _setLargeSurface(tester);

      final store = InMemoryOfflineStore(
        userId: 'officer_corrupt_ui',
        now: () => testDate,
      );
      store.simulatedCorruptNotice = true;

      final inner = FakeOfflineCampoService();
      await store.saveWorklist(inner.worklist);

      await tester.pumpWidget(
        _wrap(
          CampoHomeScreen(
            service: inner,
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Se encontró un archivo de sincronización dañado; se guardó una copia de respaldo'),
        findsOneWidget,
      );
    });
  });
}

class _FailingSyncService extends SyncService {
  _FailingSyncService({required super.campoService, required super.store});

  @override
  Future<SyncResult> sync({http.Client? client}) async {
    throw Exception('Simulated network crash');
  }
}
