import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/solicitud_credito_model.dart';
import 'package:forest_microfinance/screens/solicitud_credito_screens.dart';
import 'package:forest_microfinance/services/socio_service.dart';

class FakeSolicitudService extends SocioService {
  List<ProductoCreditoSocio> productsResponse = [
    const ProductoCreditoSocio(
      id: 2,
      codigo: 'CONS-BOB',
      nombre: 'Crédito de Consumo',
      moneda: 'BOB',
      montoMin: '1000.00',
      montoMax: '50000.00',
      plazoMinMeses: 6,
      plazoMaxMeses: 48,
      tasaInteresAnual: '18.00',
      tipoAmortizacion: 'FRANCES',
      requiereGarantia: false,
    ),
  ];

  SimulacionCredito simulationResponse = const SimulacionCredito(
    cuotaEstimada: '263.29',
    totalIntereses: '79.72',
    totalAPagar: '1579.72',
    cronograma: [
      SimulacionCuota(
        numero: 1,
        capital: '240.79',
        interes: '22.50',
        cuota: '263.29',
        saldo: '1259.21',
      ),
    ],
  );

  String? simulationError;
  String? createError;
  int createCalls = 0;
  int cancelCalls = 0;
  String? lastCancelReason;

  SolicitudCreditoItem createdItem = const SolicitudCreditoItem(
    id: 8852,
    numeroSolicitud: 'SOL-000004',
    producto: 'Crédito de Consumo',
    monto: '1500.00',
    plazoMeses: 6,
    destino: 'CONSUMO',
    estado: 'PENDIENTE',
    canalOrigen: 'MOVIL',
    fechaSolicitud: '2026-09-29T20:29:04',
    requiereEvaluacion: true,
  );

  List<SolicitudCreditoItem> requestsResponse = [
    const SolicitudCreditoItem(
      id: 8852,
      numeroSolicitud: 'SOL-000004',
      producto: 'Crédito de Consumo',
      monto: '1500.00',
      plazoMeses: 6,
      destino: 'CONSUMO',
      estado: 'PENDIENTE',
      canalOrigen: 'MOVIL',
      fechaSolicitud: '2026-09-29T20:29:04',
      requiereEvaluacion: true,
    ),
    const SolicitudCreditoItem(
      id: 5429,
      numeroSolicitud: 'SOL-000003',
      producto: 'Crédito de Consumo',
      monto: '1200.00',
      plazoMeses: 6,
      destino: 'CONSUMO',
      estado: 'DESEMBOLSADO',
      canalOrigen: 'VENTANILLA',
      fechaSolicitud: '2026-09-27T20:21:36',
      requiereEvaluacion: false,
    ),
  ];

  SolicitudCreditoDetalle detailResponse = const SolicitudCreditoDetalle(
    id: 8852,
    numeroSolicitud: 'SOL-000004',
    producto: 'Crédito de Consumo',
    monto: '1500.00',
    plazoMeses: 6,
    destino: 'CONSUMO',
    estado: 'PENDIENTE',
    canalOrigen: 'MOVIL',
    fechaSolicitud: '2026-09-29T20:29:04',
    requiereEvaluacion: true,
    lineaTiempo: [
      TimelineEvent(
        estado: 'PENDIENTE',
        fecha: '2026-09-29T20:29:04',
      ),
    ],
  );

  @override
  Future<SocioResult<List<ProductoCreditoSocio>>> creditProducts({
    http.Client? client,
  }) async {
    return SocioResult.success(productsResponse);
  }

  @override
  Future<SocioResult<SimulacionCredito>> simulateCredit({
    required int productId,
    required String amount,
    required int termMonths,
    http.Client? client,
  }) async {
    if (simulationError != null) {
      return SocioResult.failure(simulationError);
    }
    return SocioResult.success(simulationResponse);
  }

  @override
  Future<SocioResult<SolicitudCreditoItem>> createCreditRequest({
    required int productId,
    required String amount,
    required int termMonths,
    required String destination,
    String? destinationDetail,
    required DatosDeclarados declaredData,
    http.Client? client,
  }) async {
    createCalls++;
    if (createError != null) {
      return SocioResult.failure(createError);
    }
    return SocioResult.success(createdItem);
  }

  @override
  Future<SocioResult<List<SolicitudCreditoItem>>> creditRequests({
    http.Client? client,
  }) async {
    return SocioResult.success(requestsResponse);
  }

  @override
  Future<SocioResult<SolicitudCreditoDetalle>> creditRequestDetail(
    int requestId, {
    http.Client? client,
  }) async {
    return SocioResult.success(detailResponse);
  }

  @override
  Future<SocioResult<SolicitudCreditoItem>> cancelCreditRequest(
    int requestId, {
    required String reason,
    http.Client? client,
  }) async {
    cancelCalls++;
    lastCancelReason = reason;
    return const SocioResult.success(
      SolicitudCreditoItem(
        id: 8852,
        numeroSolicitud: 'SOL-000004',
        producto: 'Crédito de Consumo',
        monto: '1500.00',
        plazoMeses: 6,
        destino: 'CONSUMO',
        estado: 'ANULADA',
        canalOrigen: 'MOVIL',
        fechaSolicitud: '2026-09-29T20:29:04',
        requiereEvaluacion: true,
        motivo: 'Ya no necesito el crédito',
      ),
    );
  }
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(home: child),
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
  testWidgets('ProductosCreditoScreen displays products and navigates to simulator', (tester) async {
    final service = FakeSolicitudService();
    await tester.pumpWidget(_wrap(ProductosCreditoScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Crédito de Consumo'), findsOneWidget);
    expect(find.text('CONS-BOB'), findsOneWidget);
    expect(find.textContaining('1000.00'), findsWidgets);
    expect(find.textContaining('18.00%'), findsOneWidget);

    await tester.tap(find.text('Simular crédito').first);
    await tester.pumpAndSettle();

    expect(find.byType(SimuladorCreditoScreen), findsOneWidget);
  });

  testWidgets('SimuladorCreditoScreen simulates installment and shows schedule', (tester) async {
    _setLargeSurface(tester);
    final service = FakeSolicitudService();
    final product = service.productsResponse.first;

    await tester.pumpWidget(_wrap(SimuladorCreditoScreen(producto: product, service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Simulador de Crédito'), findsOneWidget);

    // Enter amount and term
    final montoField = find.byKey(const Key('simulador_monto_field'));
    final plazoField = find.byKey(const Key('simulador_plazo_field'));

    await tester.enterText(montoField, '1500.00');
    await tester.enterText(plazoField, '6');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('simulador_calcular_btn')));
    await tester.pumpAndSettle();

    expect(find.textContaining('263.29'), findsWidgets);
    expect(find.textContaining('79.72'), findsWidgets);
    expect(find.textContaining('1579.72'), findsWidgets);

    // Check continue button
    final continueBtn = find.text('Continuar con la solicitud');
    await tester.ensureVisible(continueBtn);
    expect(continueBtn, findsOneWidget);
  });

  testWidgets('SimuladorCreditoScreen displays backend 422 error detail', (tester) async {
    final service = FakeSolicitudService();
    service.simulationError = 'El monto está fuera del rango permitido para el producto';
    final product = service.productsResponse.first;

    await tester.pumpWidget(_wrap(SimuladorCreditoScreen(producto: product, service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('simulador_calcular_btn')));
    await tester.pumpAndSettle();

    expect(find.text('El monto está fuera del rango permitido para el producto'), findsOneWidget);
  });

  testWidgets('FormularioSolicitudScreen validates fields and navigates to summary', (tester) async {
    _setLargeSurface(tester);
    final service = FakeSolicitudService();
    final product = service.productsResponse.first;

    await tester.pumpWidget(_wrap(FormularioSolicitudScreen(
      producto: product,
      monto: '1500.00',
      plazoMeses: 6,
      cuotaEstimada: '263.29',
      service: service,
    )));
    await tester.pumpAndSettle();

    // Tap review without filling fields
    final revisarBtn = find.byKey(const Key('formulario_revisar_btn'));
    await tester.ensureVisible(revisarBtn);
    await tester.tap(revisarBtn);
    await tester.pumpAndSettle();

    // Shows validation error for income and activity
    expect(find.text('Ingrese sus ingresos mensuales'), findsOneWidget);

    // Fill valid data
    await tester.enterText(find.byKey(const Key('formulario_actividad_field')), 'Comercio minorista');
    await tester.enterText(find.byKey(const Key('formulario_ingresos_field')), '3500.00');
    await tester.enterText(find.byKey(const Key('formulario_egresos_field')), '1200.00');
    await tester.pumpAndSettle();

    await tester.ensureVisible(revisarBtn);
    await tester.tap(revisarBtn);
    await tester.pumpAndSettle();

    expect(find.byType(ResumenSolicitudScreen), findsOneWidget);
  });

  testWidgets('ResumenSolicitudScreen handles 409 conflict error display', (tester) async {
    final service = FakeSolicitudService();
    service.createError = 'El socio ya tiene una solicitud en curso';
    final product = service.productsResponse.first;

    await tester.pumpWidget(_wrap(ResumenSolicitudScreen(
      producto: product,
      monto: '1500.00',
      plazoMeses: 6,
      cuotaEstimada: '263.29',
      destino: 'CONSUMO',
      destinoDetalle: 'Compra de electrodomésticos',
      datosDeclarados: const DatosDeclarados(
        ingresoMensual: '3500.00',
        egresoMensual: '1200.00',
        actividadEconomica: 'Comercio minorista',
        fuenteIngresos: 'DEPENDIENTE',
      ),
      service: service,
    )));
    await tester.pumpAndSettle();

    final confirmarBtn = find.byKey(const Key('resumen_confirmar_btn'));
    await tester.ensureVisible(confirmarBtn);
    await tester.tap(confirmarBtn);
    await tester.pumpAndSettle();

    expect(find.text('El socio ya tiene una solicitud en curso'), findsOneWidget);
    expect(service.createCalls, 1);
  });

  testWidgets('MisSolicitudesScreen shows requests and chips, and Detalle allows cancellation', (tester) async {
    final service = FakeSolicitudService();
    await tester.pumpWidget(_wrap(MisSolicitudesScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('SOL-000004'), findsOneWidget);
    expect(find.text('PENDIENTE'), findsOneWidget);
    expect(find.text('SOL-000003'), findsOneWidget);
    expect(find.text('DESEMBOLSADO'), findsOneWidget);

    // Tap first request to see detail
    await tester.tap(find.text('SOL-000004'));
    await tester.pumpAndSettle();

    expect(find.byType(DetalleSolicitudScreen), findsOneWidget);
    expect(find.text('Línea de tiempo'), findsOneWidget);
    expect(find.text('Cancelar solicitud'), findsOneWidget);

    // Tap cancel button
    await tester.tap(find.text('Cancelar solicitud'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar solicitud de crédito'), findsOneWidget);

    // Try confirming with empty reason
    await tester.tap(find.byKey(const Key('dialog_confirmar_cancelacion_btn')));
    await tester.pumpAndSettle();
    expect(service.cancelCalls, 0);

    // Enter reason and confirm
    await tester.enterText(find.byKey(const Key('dialog_motivo_cancelacion_field')), 'Ya no necesito el crédito');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dialog_confirmar_cancelacion_btn')));
    await tester.pumpAndSettle();

    expect(service.cancelCalls, 1);
    expect(service.lastCancelReason, 'Ya no necesito el crédito');
  });
}
