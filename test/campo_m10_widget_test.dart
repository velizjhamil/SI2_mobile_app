import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/campo_model.dart';
import 'package:forest_microfinance/screens/campo_screens.dart';
import 'package:forest_microfinance/services/campo_service.dart';

class FakeM10CampoService extends CampoService {
  List<SocioPrecalificacion> sociosResponse = [
    const SocioPrecalificacion(
      id: 3,
      ci: '5551234',
      nombre: 'Sofia',
      apellido: 'Socia',
    ),
    const SocioPrecalificacion(
      id: 4,
      ci: '5559876',
      nombre: 'Mateo',
      apellido: 'Terceros',
    ),
  ];

  List<ProductoPrecalificacion> productosResponse = [
    const ProductoPrecalificacion(
      id: 2,
      codigo: 'CONS-BOB',
      nombre: 'Crédito de Consumo',
      monedaSimbolo: 'Bs.',
      montoMin: '1000.00',
      montoMax: '50000.00',
      plazoMinMeses: 6,
      plazoMaxMeses: 48,
      tasaInteresAnual: '18.00',
      requiereGarantia: false,
    ),
    const ProductoPrecalificacion(
      id: 1,
      codigo: 'MICRO-BOB',
      nombre: 'Microcrédito Productivo',
      monedaSimbolo: 'Bs.',
      montoMin: '2000.00',
      montoMax: '100000.00',
      plazoMinMeses: 6,
      plazoMaxMeses: 60,
      tasaInteresAnual: '15.00',
      requiereGarantia: true,
    ),
  ];

  PrecalificacionResultado? precalificacionResponse;
  String? precalificacionError;
  PrecalificacionForm? lastSubmittedForm;
  int precalificarCalls = 0;

  @override
  Future<CampoResult<List<SocioPrecalificacion>>> getSociosActivos({
    http.Client? client,
  }) async {
    return CampoResult.success(sociosResponse);
  }

  @override
  Future<CampoResult<List<ProductoPrecalificacion>>> getProductosActivos({
    http.Client? client,
  }) async {
    return CampoResult.success(productosResponse);
  }

  @override
  Future<CampoResult<PrecalificacionResultado>> precalificar(
    PrecalificacionForm form, {
    http.Client? client,
  }) async {
    precalificarCalls++;
    lastSubmittedForm = form;
    if (precalificacionError != null) {
      return CampoResult.failure(precalificacionError);
    }
    return CampoResult.success(precalificacionResponse!);
  }

  @override
  Future<CampoResult<List<SolicitudResumenCampo>>> getWorklist({
    bool requiereEvaluacion = true,
    String? canalOrigen,
    http.Client? client,
  }) async {
    return const CampoResult.success([]);
  }
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('CU-M10 Precalificación Widget Tests', () {
    testWidgets('CampoHomeScreen has Precalificar button that navigates to PrecalificacionScreen',
        (tester) async {
      _setLargeSurface(tester);
      final service = FakeM10CampoService();

      await tester.pumpWidget(_wrap(CampoHomeScreen(service: service)));
      await tester.pumpAndSettle();

      final navBtn = find.byKey(const Key('campo_precalificar_nav_btn'));
      expect(navBtn, findsOneWidget);

      await tester.tap(navBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PrecalificacionScreen), findsOneWidget);
      expect(find.text('Precalificación en Campo'), findsOneWidget);
    });

    testWidgets('PrecalificacionScreen validates form fields and product ranges',
        (tester) async {
      _setLargeSurface(tester);
      final service = FakeM10CampoService();

      await tester.pumpWidget(_wrap(PrecalificacionScreen(service: service)));
      await tester.pumpAndSettle();

      // Product dropdown displays ranges
      expect(
        find.textContaining('Crédito de Consumo (1000.00 - 50000.00 Bs. · 6-48 m)'),
        findsOneWidget,
      );

      // Tap Precalificar without selecting a socio
      final submitBtn = find.byKey(const Key('precal_calcular_btn'));
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Debe seleccionar un socio'), findsOneWidget);
      expect(service.precalificarCalls, 0);

      // Select socio via picker
      await tester.tap(find.byKey(const Key('precal_seleccionar_socio_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Buscar Socio Activo'), findsOneWidget);
      // Filter by CI
      await tester.enterText(find.byKey(const Key('precal_socio_search_field')), '5551234');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('precal_socio_tile_3')));
      await tester.pumpAndSettle();

      expect(find.text('Sofia Socia'), findsOneWidget);

      // Enter amount out of product range (e.g. 999999 where max is 50000)
      await tester.enterText(find.byKey(const Key('precal_monto_field')), '999999');
      await tester.enterText(find.byKey(const Key('precal_plazo_field')), '2'); // Min is 6
      await tester.enterText(find.byKey(const Key('precal_ingreso_field')), '0'); // Must be > 0
      await tester.enterText(find.byKey(const Key('precal_egreso_field')), '-10'); // Cannot be < 0
      await tester.enterText(find.byKey(const Key('precal_antiguedad_field')), '-5'); // Cannot be < 0

      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('El monto debe estar entre 1000.00 y 50000.00 Bs.'),
        findsOneWidget,
      );
      expect(
        find.text('El plazo debe estar entre 6 y 48 meses'),
        findsOneWidget,
      );
      expect(find.text('El ingreso debe ser mayor a 0'), findsOneWidget);
      expect(find.text('El egreso no puede ser negativo'), findsOneWidget);
      expect(find.text('La antigüedad debe ser mayor o igual a 0'), findsOneWidget);

      expect(service.precalificarCalls, 0);
    });

    testWidgets('PrecalificacionScreen approved result displays score, badge, cuota, risk, and no-solicitud banner',
        (tester) async {
      _setLargeSurface(tester);
      final service = FakeM10CampoService();
      service.precalificacionResponse = const PrecalificacionResultado(
        precalificacion: true,
        score: 910,
        dictamen: 'APROBADO',
        cuotaEstimada: '399.39',
        relacionCuotaIngreso: '6.66',
        probabilidadMora: '0.0492',
        nivelRiesgo: 'BAJO',
        socioNombre: 'Sofia Socia',
        socioCi: '5551234',
        productoNombre: 'Crédito de Consumo',
        factores: [
          ScoringFactor(
            codigo: 'CAPACIDAD_PAGO',
            descripcion: 'Relación cuota-ingreso respecto al máximo del producto',
            puntos: 300,
            maximo: 300,
            valor: '6.66% de 40.00%',
            motivo: 'La relación es igual o menor al 50% del máximo permitido.',
          ),
        ],
        knockouts: [],
      );

      await tester.pumpWidget(_wrap(PrecalificacionScreen(service: service)));
      await tester.pumpAndSettle();

      // Select socio
      await tester.tap(find.byKey(const Key('precal_seleccionar_socio_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('precal_socio_tile_3')));
      await tester.pumpAndSettle();

      // Fill valid values
      await tester.enterText(find.byKey(const Key('precal_monto_field')), '8000');
      await tester.enterText(find.byKey(const Key('precal_plazo_field')), '24');
      await tester.enterText(find.byKey(const Key('precal_ingreso_field')), '6000');
      await tester.enterText(find.byKey(const Key('precal_egreso_field')), '2000');
      await tester.enterText(find.byKey(const Key('precal_deudas_field')), '0.00');
      await tester.enterText(find.byKey(const Key('precal_antiguedad_field')), '48');

      final submitBtn = find.byKey(const Key('precal_calcular_btn'));
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(service.precalificarCalls, 1);
      expect(find.byType(PrecalificacionResultadoScreen), findsOneWidget);

      // Verify prominent label 'Precalificación — no es una solicitud'
      expect(find.byKey(const Key('precal_banner_no_solicitud')), findsOneWidget);
      expect(find.text('Precalificación — no es una solicitud'), findsOneWidget);

      // Score and dictamen
      expect(find.byKey(const Key('precal_dictamen_badge')), findsOneWidget);
      expect(find.text('APROBADO'), findsOneWidget);
      expect(find.byKey(const Key('precal_score_text')), findsOneWidget);
      expect(find.text('910 / 1000 pts'), findsOneWidget);

      // Cuota, mora, riesgo
      expect(find.textContaining('399.39 BOB'), findsOneWidget);
      expect(find.textContaining('BAJO'), findsOneWidget);
      expect(find.textContaining('4.9%'), findsOneWidget);

      // Factors rendered
      expect(find.byKey(const Key('precal_factores_section')), findsOneWidget);
      expect(find.textContaining('Relación cuota-ingreso respecto al máximo'), findsOneWidget);
      expect(find.textContaining('300/300 pts'), findsOneWidget);

      // No knockouts section for approved result without knockouts
      expect(find.byKey(const Key('precal_knockouts_section')), findsNothing);
    });

    testWidgets('PrecalificacionScreen rejected result renders knockouts section first',
        (tester) async {
      _setLargeSurface(tester);
      final service = FakeM10CampoService();
      service.precalificacionResponse = const PrecalificacionResultado(
        precalificacion: true,
        score: 650,
        dictamen: 'RECHAZADO',
        cuotaEstimada: '399.39',
        relacionCuotaIngreso: '26.63',
        probabilidadMora: '0.3178',
        nivelRiesgo: 'MEDIO',
        socioNombre: 'Sofia Socia',
        socioCi: '5551234',
        productoNombre: 'Crédito de Consumo',
        knockouts: [
          ScoringKnockout(
            codigo: 'CUOTA_SUPERA_CAPACIDAD',
            descripcion: 'La cuota estimada supera la capacidad de pago disponible.',
            efecto: 'RECHAZADO',
          ),
          ScoringKnockout(
            codigo: 'CALIFICACION_ASFI_CRITICA',
            descripcion: 'La calificación ASFI E o F requiere rechazo.',
            efecto: 'RECHAZADO',
          ),
        ],
        factores: [
          ScoringFactor(
            codigo: 'CALIFICACION_ASFI',
            descripcion: 'Calificación de riesgo ASFI',
            puntos: 0,
            maximo: 200,
            valor: 'E',
            motivo: 'La categoría E asigna 0 puntos.',
          ),
        ],
      );

      await tester.pumpWidget(_wrap(PrecalificacionScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('precal_seleccionar_socio_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('precal_socio_tile_3')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('precal_monto_field')), '8000');
      await tester.enterText(find.byKey(const Key('precal_plazo_field')), '24');
      await tester.enterText(find.byKey(const Key('precal_ingreso_field')), '1500');
      await tester.enterText(find.byKey(const Key('precal_egreso_field')), '1400');
      await tester.enterText(find.byKey(const Key('precal_deudas_field')), '0.00');
      await tester.enterText(find.byKey(const Key('precal_antiguedad_field')), '48');

      final submitBtn = find.byKey(const Key('precal_calcular_btn'));
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PrecalificacionResultadoScreen), findsOneWidget);
      expect(find.text('RECHAZADO'), findsOneWidget);
      expect(find.text('650 / 1000 pts'), findsOneWidget);

      // Knockouts rendered first
      expect(find.byKey(const Key('precal_knockouts_section')), findsOneWidget);
      expect(find.text('Reglas de Excepción (Knockouts)'), findsOneWidget);
      expect(
        find.textContaining('La cuota estimada supera la capacidad de pago disponible.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('La calificación ASFI E o F requiere rechazo.'),
        findsOneWidget,
      );
    });

    testWidgets('PrecalificacionScreen displays backend error message on 400 or 404',
        (tester) async {
      _setLargeSurface(tester);
      final service = FakeM10CampoService();
      service.precalificacionError = 'Socio no encontrado';

      await tester.pumpWidget(_wrap(PrecalificacionScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('precal_seleccionar_socio_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('precal_socio_tile_3')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('precal_monto_field')), '8000');
      await tester.enterText(find.byKey(const Key('precal_plazo_field')), '24');
      await tester.enterText(find.byKey(const Key('precal_ingreso_field')), '6000');
      await tester.enterText(find.byKey(const Key('precal_egreso_field')), '2000');
      await tester.enterText(find.byKey(const Key('precal_deudas_field')), '0.00');
      await tester.enterText(find.byKey(const Key('precal_antiguedad_field')), '48');

      final submitBtn = find.byKey(const Key('precal_calcular_btn'));
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PrecalificacionResultadoScreen), findsNothing);
      expect(find.byKey(const Key('precal_error_banner')), findsOneWidget);
      expect(find.text('Socio no encontrado'), findsWidgets);
    });
  });
}
