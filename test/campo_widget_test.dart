import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/campo_model.dart';
import 'package:forest_microfinance/screens/campo_screens.dart';
import 'package:forest_microfinance/services/campo_service.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/secure_token_store.dart';

class FakeCampoService extends CampoService {
  int worklistCalls = 0;
  String? lastCanalFilter;
  int getFichaCalls = 0;
  int saveCalls = 0;
  int scoringCalls = 0;
  String? scoringError;

  List<SolicitudResumenCampo> worklistResponse = [
    const SolicitudResumenCampo(
      id: 9008,
      numeroSolicitud: 'SOL-000005',
      fechaSolicitud: '2026-09-29T22:48:08',
      estado: 'PENDIENTE',
      socioNombre: 'Sofia Socia',
      socioCi: '5551234',
      productoNombre: 'Crédito de Consumo',
      monedaSimbolo: 'Bs.',
      monto: '3000.00',
      plazoMeses: 12,
      destino: 'CONSUMO',
      canalOrigen: 'MOVIL',
      requiereEvaluacion: true,
    ),
  ];

  FichaCampo fichaResponse = const FichaCampo(
    solicitud: FichaCampoSolicitud(
      id: 9008,
      numeroSolicitud: 'SOL-000005',
      producto: 'Crédito de Consumo',
      monto: '3000.00',
      plazoMeses: 12,
      destino: 'CONSUMO',
      destinoDetalle: 'Equipamiento del hogar',
      estado: 'PENDIENTE',
      canalOrigen: 'MOVIL',
      requiereEvaluacion: true,
    ),
    socio: FichaCampoSocio(
      id: 3,
      nombreCompleto: 'Sofia Socia',
      ci: '5551234',
      telefono: null,
      direccion: null,
    ),
    datosDeclarados: FichaCampoDatosDeclarados(
      ingresoMensual: '5200.00',
      egresoMensual: '2100.00',
      actividadEconomica: 'Venta de abarrotes',
      fuenteIngresos: 'INDEPENDIENTE',
    ),
    evaluacion: null,
    catalogos: CatalogosFichaCampo(
      fuentesIngresos: ['DEPENDIENTE', 'INDEPENDIENTE', 'MIXTO'],
      calificacionesAsfi: ['A', 'B', 'C', 'D', 'E', 'F'],
    ),
  );

  ScoringResultado scoringResponse = const ScoringResultado(
    id: 1507,
    solicitudId: 9008,
    score: 910,
    dictamen: 'APROBADO',
    factores: [
      ScoringFactor(
        codigo: 'CAPACIDAD_PAGO',
        descripcion: 'Relación cuota-ingreso',
        puntos: 300,
        maximo: 300,
        valor: '5.50%',
        motivo: 'Excelente capacidad de pago',
      ),
    ],
    explicacion: 'Dictamen APROBADO con puntaje 910/1000.',
  );

  @override
  Future<CampoResult<List<SolicitudResumenCampo>>> getWorklist({
    bool requiereEvaluacion = true,
    String? canalOrigen,
    http.Client? client,
  }) async {
    worklistCalls++;
    lastCanalFilter = canalOrigen;
    return CampoResult.success(worklistResponse);
  }

  @override
  Future<CampoResult<FichaCampo>> getFichaCampo(
    int solicitudId, {
    http.Client? client,
  }) async {
    getFichaCalls++;
    return CampoResult.success(fichaResponse);
  }

  @override
  Future<CampoResult<SolicitudResumenCampo>> guardarEvaluacion(
    int solicitudId,
    EvaluacionCampoForm form, {
    http.Client? client,
  }) async {
    saveCalls++;
    return const CampoResult.success(
      SolicitudResumenCampo(
        id: 9008,
        numeroSolicitud: 'SOL-000005',
        fechaSolicitud: '2026-09-29T22:48:08',
        estado: 'PENDIENTE',
        socioNombre: 'Sofia Socia',
        socioCi: '5551234',
        productoNombre: 'Crédito de Consumo',
        monedaSimbolo: 'Bs.',
        monto: '3000.00',
        plazoMeses: 12,
        destino: 'CONSUMO',
        canalOrigen: 'MOVIL',
        requiereEvaluacion: false,
      ),
    );
  }

  @override
  Future<CampoResult<ScoringResultado>> calcularScoring(
    int solicitudId, {
    http.Client? client,
  }) async {
    scoringCalls++;
    if (scoringError != null) {
      return CampoResult.failure(scoringError);
    }
    return CampoResult.success(scoringResponse);
  }
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(
      routes: {
        '/login': (_) => const Scaffold(body: Text('Login Screen Mock')),
      },
      home: child,
    ),
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('CampoHomeScreen displays worklist, channel filter, and navigates to FichaCampoScreen', (tester) async {
    final service = FakeCampoService();
    await tester.pumpWidget(_wrap(CampoHomeScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Módulo de Campo'), findsOneWidget);
    expect(find.text('SOL-000005'), findsOneWidget);
    expect(find.textContaining('Sofia Socia'), findsOneWidget);
    expect(find.textContaining('3000.00 Bs.'), findsOneWidget);
    expect(find.text('MOVIL'), findsWidgets);

    // Tap channel filter chip 'VENTANILLA'
    await tester.tap(find.byKey(const Key('filter_canal_ventanilla')));
    await tester.pumpAndSettle();

    expect(service.lastCanalFilter, 'VENTANILLA');

    // Tap on request item to open FichaCampoScreen
    await tester.tap(find.text('SOL-000005'));
    await tester.pumpAndSettle();

    expect(find.byType(FichaCampoScreen), findsOneWidget);
  });

  testWidgets('CampoHomeScreen displays friendly empty state when list is empty', (tester) async {
    final service = FakeCampoService();
    service.worklistResponse = [];

    await tester.pumpWidget(_wrap(CampoHomeScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('No hay solicitudes pendientes de evaluación.'), findsOneWidget);
  });

  testWidgets('CampoHomeScreen logout button clears token and navigates to /login', (tester) async {
    AuthService.currentStore = InMemorySecureTokenStore();
    AuthService.tokenJWT = 'active-token';
    final service = FakeCampoService();

    await tester.pumpWidget(_wrap(CampoHomeScreen(service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('campo_logout_btn')));
    await tester.pumpAndSettle();

    expect(find.text('¿Desea cerrar la sesión de Oficial de Crédito?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dialog_confirm_logout_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Login Screen Mock'), findsOneWidget);
    expect(AuthService.tokenJWT, isNull);
  });

  testWidgets('FichaCampoScreen displays socio data (nulls with "—"), reference declared data, and evaluation form', (tester) async {
    _setLargeSurface(tester);
    final service = FakeCampoService();

    await tester.pumpWidget(_wrap(FichaCampoScreen(solicitudId: 9008, service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Ficha de Campo'), findsOneWidget);
    expect(find.text('Sofia Socia'), findsOneWidget);
    expect(find.text('5551234'), findsOneWidget);
    // Null contact displays "—"
    expect(find.text('—'), findsWidgets);

    // Declared data reference
    expect(find.textContaining('5200.00'), findsWidgets);
    expect(find.textContaining('Venta de abarrotes'), findsWidgets);

    // Evaluation form fields
    final ingresoField = find.byKey(const Key('eval_ingreso_field'));
    final egresoField = find.byKey(const Key('eval_egreso_field'));
    final deudasField = find.byKey(const Key('eval_deudas_field'));
    final actividadField = find.byKey(const Key('eval_actividad_field'));
    final antiguedadField = find.byKey(const Key('eval_antiguedad_field'));

    await tester.enterText(ingresoField, '5000.00');
    await tester.enterText(egresoField, '2000.00');
    await tester.enterText(deudasField, '0.00');
    await tester.enterText(actividadField, 'Venta de abarrotes en mercado');
    await tester.enterText(antiguedadField, '48');
    await tester.pumpAndSettle();

    // Tap guardar evaluación
    final guardarBtn = find.byKey(const Key('eval_guardar_btn'));
    await tester.ensureVisible(guardarBtn);
    await tester.tap(guardarBtn);
    await tester.pumpAndSettle();

    expect(service.saveCalls, 1);
  });

  testWidgets('FichaCampoScreen calculates scoring and renders score, dictamen, and factors', (tester) async {
    _setLargeSurface(tester);
    final service = FakeCampoService();

    await tester.pumpWidget(_wrap(FichaCampoScreen(solicitudId: 9008, service: service)));
    await tester.pumpAndSettle();

    final scoringBtn = find.byKey(const Key('eval_calcular_scoring_btn'));
    await tester.ensureVisible(scoringBtn);
    await tester.tap(scoringBtn);
    await tester.pumpAndSettle();

    expect(service.scoringCalls, 1);
    expect(find.text('Dictamen: APROBADO'), findsOneWidget);
    expect(find.textContaining('910 / 1000'), findsOneWidget);
    expect(find.text('Relación cuota-ingreso'), findsOneWidget);
  });

  testWidgets('FichaCampoScreen displays backend detail error when scoring fails with 422', (tester) async {
    _setLargeSurface(tester);
    final service = FakeCampoService();
    service.scoringError = 'Falta la evaluación de campo del oficial';

    await tester.pumpWidget(_wrap(FichaCampoScreen(solicitudId: 9008, service: service)));
    await tester.pumpAndSettle();

    final scoringBtn = find.byKey(const Key('eval_calcular_scoring_btn'));
    await tester.ensureVisible(scoringBtn);
    await tester.tap(scoringBtn);
    await tester.pumpAndSettle();

    expect(find.text('Falta la evaluación de campo del oficial'), findsOneWidget);
  });
}
