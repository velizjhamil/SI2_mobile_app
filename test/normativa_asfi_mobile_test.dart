import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/reclamo_model.dart';
import 'package:forest_microfinance/models/reprogramacion_model.dart';
import 'package:forest_microfinance/models/socio_model.dart';
import 'package:forest_microfinance/screens/reclamos_screen.dart';
import 'package:forest_microfinance/screens/reprogramacion_screen.dart';
import 'package:forest_microfinance/screens/socio_screens.dart';
import 'package:forest_microfinance/screens/solicitud_credito_screens.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/socio_service.dart';

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

class FakeNormativaService extends SocioService {
  List<ReclamoItem> claimsResponse = [];
  List<ReprogramacionCreditoItem> reschedulingResponse = [];
  CreditSchedule? scheduleResponse;
  int createClaimCalls = 0;
  int registerConformityCalls = 0;
  int requestReschedulingCalls = 0;
  bool? lastConforme;
  String? lastMotivo;

  @override
  Future<SocioResult<List<ReclamoItem>>> claims({http.Client? client}) async {
    return SocioResult.success(claimsResponse);
  }

  @override
  Future<SocioResult<ReclamoItem>> createClaim({
    required String tipo,
    required String descripcion,
    int? creditoId,
    http.Client? client,
  }) async {
    createClaimCalls++;
    final claim = ReclamoItem(
      id: 99,
      numeroReclamo: 'PR-2026-000099',
      socioId: 1,
      socio: 'Juan Perez',
      creditoId: creditoId,
      tipo: tipo,
      descripcion: descripcion,
      canal: 'MOVIL',
      estado: 'REGISTRADO',
      fechaRegistro: '2026-11-22T08:00:00',
      fechaLimiteRespuesta: '2026-11-27T08:00:00',
      vencido: false,
    );
    return SocioResult.success(claim);
  }

  @override
  Future<SocioResult<ReclamoItem>> registerConformity(
    int reclamoId, {
    required bool conforme,
    String? motivo,
    http.Client? client,
  }) async {
    registerConformityCalls++;
    lastConforme = conforme;
    lastMotivo = motivo;
    final updated = ReclamoItem(
      id: reclamoId,
      numeroReclamo: 'PR-2026-000001',
      socioId: 1,
      socio: 'Juan Perez',
      tipo: 'CREDITO',
      descripcion: 'Detalle',
      canal: 'MOVIL',
      estado: conforme ? 'CERRADO' : 'ESCALADO_ASFI',
      fechaRegistro: '2026-11-20T08:00:00',
      fechaLimiteRespuesta: '2026-11-25T08:00:00',
      vencido: false,
      conforme: conforme,
      motivoDisconformidad: motivo,
    );
    return SocioResult.success(updated);
  }

  @override
  Future<SocioResult<List<ReprogramacionCreditoItem>>> creditReschedulingHistory(
    int creditId, {
    http.Client? client,
  }) async {
    return SocioResult.success(reschedulingResponse);
  }

  @override
  Future<SocioResult<ReprogramacionCreditoItem>> requestRescheduling(
    int creditId, {
    required int nuevoPlazoMeses,
    required String motivo,
    http.Client? client,
  }) async {
    requestReschedulingCalls++;
    final item = ReprogramacionCreditoItem(
      id: 50,
      creditoId: creditId,
      numeroCredito: 'CR-100',
      estado: 'SOLICITADA',
      canal: 'MOVIL',
      motivo: motivo,
      nuevoPlazoMeses: nuevoPlazoMeses,
      saldoCapital: '45000.00',
      fechaSolicitud: '2026-11-22T08:00:00',
    );
    return SocioResult.success(item);
  }

  @override
  Future<SocioResult<CreditSchedule>> creditSchedule(
    int creditId, {
    http.Client? client,
  }) async {
    if (scheduleResponse != null) {
      return SocioResult.success(scheduleResponse);
    }
    return super.creditSchedule(creditId, client: client);
  }

  @override
  Future<SocioResult<List<SocioCredit>>> credits({http.Client? client}) async {
    return const SocioResult.success([
      SocioCredit(
        id: 1,
        number: 'CR-100',
        product: 'Vivienda Social',
        currency: 'BOB',
        disbursedAmount: '50000.00',
        outstandingBalance: '45000.00',
        status: 'VIGENTE',
        nextInstallment: CreditInstallment(
          number: 2,
          dueDate: '2026-12-15',
          totalAmount: '1200.00',
        ),
      ),
    ]);
  }
}

void main() {
  final previousToken = AuthService.tokenJWT;
  setUp(() {
    AuthService.tokenJWT = 'test-token-jwt';
  });
  tearDown(() {
    AuthService.tokenJWT = previousToken;
  });

  group('Normativa ASFI Models & Parsing', () {
    test('ViviendaSocialData serializes and deserializes cleanly', () {
      const vis = ViviendaSocialData(
        valorVivienda: '350000.00',
        tipoInmueble: 'CASA',
        unicaVivienda: true,
      );
      final json = vis.toJson();
      expect(json['valor_vivienda'], 350000.0);
      expect(json['tipo_inmueble'], 'CASA');
      expect(json['unica_vivienda'], true);

      final fromJson = ViviendaSocialData.fromJson({
        'valor_vivienda': '280000.00',
        'tipo_inmueble': 'DEPARTAMENTO',
        'unica_vivienda': true,
      });
      expect(fromJson.valorVivienda, '280000.00');
      expect(fromJson.tipoInmueble, 'DEPARTAMENTO');
      expect(fromJson.unicaVivienda, true);
    });

    test('ProductoCreditoSocio identifies VIS products', () {
      final p1 = ProductoCreditoSocio.fromJson({
        'id': 1,
        'codigo': 'VIS-01',
        'nombre': 'Crédito de Vivienda',
        'moneda': 'BOB',
        'monto_min': '10000.00',
        'monto_max': '400000.00',
        'plazo_min_meses': 12,
        'plazo_max_meses': 240,
        'tasa_interes_anual': '5.50',
        'tipo_amortizacion': 'FRANCES',
        'requiere_garantia': true,
        'tipo_credito_asfi': 'VIVIENDA_SOCIAL',
      });
      expect(p1.isViviendaSocial, isTrue);

      final p2 = ProductoCreditoSocio.fromJson({
        'id': 2,
        'codigo': 'VIS-02',
        'nombre': 'Crédito Vivienda Social DS 1842',
        'moneda': 'BOB',
        'monto_min': '10000.00',
        'monto_max': '400000.00',
        'plazo_min_meses': 12,
        'plazo_max_meses': 240,
        'tasa_interes_anual': '5.50',
        'tipo_amortizacion': 'FRANCES',
        'requiere_garantia': true,
      });
      expect(p2.isViviendaSocial, isTrue);

      final p3 = ProductoCreditoSocio.fromJson({
        'id': 3,
        'codigo': 'CONS-01',
        'nombre': 'Consumo Libre',
        'moneda': 'BOB',
        'monto_min': '1000.00',
        'monto_max': '50000.00',
        'plazo_min_meses': 6,
        'plazo_max_meses': 36,
        'tasa_interes_anual': '18.00',
        'tipo_amortizacion': 'FRANCES',
        'requiere_garantia': false,
        'tipo_credito_asfi': 'CONSUMO',
      });
      expect(p3.isViviendaSocial, isFalse);
    });

    test('SimulacionCredito parses TEA and TEAC', () {
      final sim = SimulacionCredito.fromJson({
        'cuota_estimada': '1250.00',
        'total_intereses': '5000.00',
        'total_seguro': '300.00',
        'total_a_pagar': '55300.00',
        'tea': '5.64',
        'teac': '6.12',
        'cronograma': [],
      });
      expect(sim.tea, '5.64');
      expect(sim.teac, '6.12');
    });

    test('CreditSchedule parses TEA, TEAC and handles REPROGRAMADA installments', () {
      final schedule = CreditSchedule.fromJson({
        'credito': {
          'id': 10,
          'numero_credito': 'CR-0010',
          'moneda': 'BOB',
          'saldo_pendiente': '40000.00',
        },
        'total_seguro': '250.00',
        'tea': '18.00',
        'teac': '19.85',
        'cuotas': [
          {
            'numero': 1,
            'fecha_vencimiento': '2026-10-15',
            'capital': '500.00',
            'interes': '150.00',
            'seguro': '25.00',
            'monto_total': '675.00',
            'saldo_capital': '39500.00',
            'estado': 'PAGADA',
            'fecha_pago': '2026-10-14',
          },
          {
            'numero': 2,
            'fecha_vencimiento': '2026-11-15',
            'capital': '500.00',
            'interes': '150.00',
            'seguro': '25.00',
            'monto_total': '675.00',
            'saldo_capital': '39000.00',
            'estado': 'REPROGRAMADA',
          },
          {
            'numero': 3,
            'fecha_vencimiento': '2026-12-15',
            'capital': '500.00',
            'interes': '150.00',
            'seguro': '25.00',
            'monto_total': '675.00',
            'saldo_capital': '38500.00',
            'estado': 'PENDIENTE',
          },
        ],
      });

      expect(schedule.tea, '18.00');
      expect(schedule.teac, '19.85');
      expect(schedule.installments.length, 3);

      final cuotaReprogramada = schedule.installments[1];
      expect(cuotaReprogramada.isReprogramada, isTrue);
      expect(cuotaReprogramada.isPaid, isFalse);
      expect(cuotaReprogramada.isVencida, isFalse);
      expect(cuotaReprogramada.isPendiente, isFalse);
    });

    test('ReclamoItem and ReprogramacionCreditoItem parse correctly', () {
      final reclamo = ReclamoItem.fromJson({
        'id': 1,
        'numero_reclamo': 'PR-2026-000001',
        'socio_id': 10,
        'socio': 'Carlos Ramos',
        'credito_id': 5,
        'tipo': 'COBRO_INDEBIDO',
        'descripcion': 'Cobro no reconocido en caja',
        'canal': 'MOVIL',
        'estado': 'RESPONDIDO',
        'fecha_registro': '2026-11-10T10:00:00',
        'fecha_limite_respuesta': '2026-11-17T10:00:00',
        'vencido': false,
        'respuesta': 'Se procedió al reembolso',
        'procedente': true,
        'fecha_respuesta': '2026-11-15T15:00:00',
      });

      expect(reclamo.numeroReclamo, 'PR-2026-000001');
      expect(reclamo.tipoLabel, 'Cobro Indebido');
      expect(reclamo.isRespondido, isTrue);
      expect(reclamo.procedente, isTrue);

      final repro = ReprogramacionCreditoItem.fromJson({
        'id': 20,
        'credito_id': 5,
        'numero_credito': 'CR-0005',
        'estado': 'APROBADA',
        'canal': 'VENTANILLA',
        'motivo': 'Disminución de ingresos',
        'nuevo_plazo_meses': 36,
        'saldo_capital': '30000.00',
        'interes_diferido': '450.00',
        'mora_condonada': '80.00',
        'plazo_anterior': 24,
        'cuotas_reprogramadas': 3,
        'fecha_solicitud': '2026-11-01T09:00:00',
        'fecha_resolucion': '2026-11-03T11:00:00',
      });

      expect(repro.isAprobada, isTrue);
      expect(repro.nuevoPlazoMeses, 36);
      expect(repro.interesDiferido, '450.00');
    });
  });

  group('SocioService Normativa ASFI Endpoints', () {
    test('createCreditRequest includes vivienda_social payload for VIS', () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/socio/solicitudes'));
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 101,
            'numero_solicitud': 'SOL-000101',
            'producto': 'Vivienda Social',
            'monto': '120000.00',
            'plazo_meses': 120,
            'destino': 'VIVIENDA',
            'estado': 'PENDIENTE',
            'canal_origen': 'MOVIL',
            'fecha_solicitud': '2026-11-22T08:00:00',
            'requiere_evaluacion': true,
          }),
          201,
        );
      });

      final service = SocioService();
      final res = await service.createCreditRequest(
        productId: 1,
        amount: '120000.00',
        termMonths: 120,
        destination: 'VIVIENDA',
        declaredData: const DatosDeclarados(
          ingresoMensual: '5000.00',
          egresoMensual: '2000.00',
          actividadEconomica: 'Ingeniero',
          fuenteIngresos: 'DEPENDIENTE',
        ),
        viviendaSocial: const ViviendaSocialData(
          valorVivienda: '350000.00',
          tipoInmueble: 'CASA',
          unicaVivienda: true,
        ),
        client: client,
      );

      expect(res.success, isTrue);
      expect(sentBody!['vivienda_social'], isNotNull);
      expect(sentBody!['vivienda_social']['tipo_inmueble'], 'CASA');
      expect(sentBody!['vivienda_social']['unica_vivienda'], true);
    });

    test('claims, createClaim, and registerConformity call expected endpoints', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/socio/reclamos')) {
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'numero_reclamo': 'PR-2026-000001',
                'socio_id': 1,
                'socio': 'Test Socio',
                'tipo': 'CREDITO',
                'descripcion': 'Cobro incorrecto',
                'canal': 'MOVIL',
                'estado': 'REGISTRADO',
                'fecha_registro': '2026-11-20T08:00:00',
                'fecha_limite_respuesta': '2026-11-25T08:00:00',
                'vencido': false,
              }
            ]),
            200,
          );
        } else if (request.method == 'POST' && request.url.path.endsWith('/socio/reclamos')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 2,
              'numero_reclamo': 'PR-2026-000002',
              'socio_id': 1,
              'socio': 'Test Socio',
              'tipo': body['tipo'],
              'descripcion': body['descripcion'],
              'canal': 'MOVIL',
              'estado': 'REGISTRADO',
              'fecha_registro': '2026-11-22T08:00:00',
              'fecha_limite_respuesta': '2026-11-27T08:00:00',
              'vencido': false,
            }),
            201,
          );
        } else if (request.method == 'POST' && request.url.path.contains('/conformidad')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 1,
              'numero_reclamo': 'PR-2026-000001',
              'socio_id': 1,
              'socio': 'Test Socio',
              'tipo': 'CREDITO',
              'descripcion': 'Cobro incorrecto',
              'canal': 'MOVIL',
              'estado': body['conforme'] == true ? 'CERRADO' : 'ESCALADO_ASFI',
              'fecha_registro': '2026-11-20T08:00:00',
              'fecha_limite_respuesta': '2026-11-25T08:00:00',
              'vencido': false,
              'conforme': body['conforme'],
              'motivo_disconformidad': body['motivo'],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = SocioService();
      final listRes = await service.claims(client: client);
      expect(listRes.success, isTrue);
      expect(listRes.value!.single.numeroReclamo, 'PR-2026-000001');

      final createRes = await service.createClaim(
        tipo: 'AHORRO',
        descripcion: 'Interés no acreditado',
        client: client,
      );
      expect(createRes.success, isTrue);
      expect(createRes.value!.numeroReclamo, 'PR-2026-000002');

      final conformRes = await service.registerConformity(
        1,
        conforme: false,
        motivo: 'Monto insuficiente',
        client: client,
      );
      expect(conformRes.success, isTrue);
      expect(conformRes.value!.estado, 'ESCALADO_ASFI');
      expect(conformRes.value!.motivoDisconformidad, 'Monto insuficiente');
    });

    test('creditReschedulingHistory and requestRescheduling call expected endpoints', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.contains('/reprogramaciones')) {
          return http.Response(
            jsonEncode([
              {
                'id': 10,
                'credito_id': 5,
                'numero_credito': 'CR-005',
                'estado': 'SOLICITADA',
                'canal': 'MOVIL',
                'motivo': 'Prórroga por salud',
                'nuevo_plazo_meses': 18,
                'saldo_capital': '25000.00',
                'fecha_solicitud': '2026-11-21T10:00:00',
              }
            ]),
            200,
          );
        } else if (request.method == 'POST' && request.url.path.contains('/reprogramaciones')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 11,
              'credito_id': 5,
              'numero_credito': 'CR-005',
              'estado': 'SOLICITADA',
              'canal': 'MOVIL',
              'motivo': body['motivo'],
              'nuevo_plazo_meses': body['nuevo_plazo_meses'],
              'saldo_capital': '25000.00',
              'fecha_solicitud': '2026-11-22T08:00:00',
            }),
            201,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = SocioService();
      final history = await service.creditReschedulingHistory(5, client: client);
      expect(history.success, isTrue);
      expect(history.value!.single.id, 10);

      final req = await service.requestRescheduling(
        5,
        nuevoPlazoMeses: 24,
        motivo: 'Afectación económica',
        client: client,
      );
      expect(req.success, isTrue);
      expect(req.value!.nuevoPlazoMeses, 24);
    });
  });

  group('Widget Tests — Normativa ASFI UI', () {
    testWidgets('FormularioSolicitudScreen renders VIS fields when product is VIS', (tester) async {
      _setLargeSurface(tester);

      const visProduct = ProductoCreditoSocio(
        id: 1,
        codigo: 'VIS-01',
        nombre: 'Vivienda de Interés Social',
        moneda: 'BOB',
        montoMin: '10000.00',
        montoMax: '400000.00',
        plazoMinMeses: 12,
        plazoMaxMeses: 240,
        tasaInteresAnual: '5.50',
        tipoAmortizacion: 'FRANCES',
        requiereGarantia: true,
        tipoCreditoAsfi: 'VIVIENDA_SOCIAL',
      );

      await tester.pumpWidget(_wrap(const FormularioSolicitudScreen(
        producto: visProduct,
        monto: '150000.00',
        plazoMeses: 120,
        cuotaEstimada: '1628.00',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Vivienda de Interés Social (VIS)'), findsOneWidget);
      expect(find.byKey(const Key('formulario_valor_vivienda_field')), findsOneWidget);
      expect(find.byKey(const Key('formulario_tipo_inmueble_field')), findsOneWidget);
      expect(find.byKey(const Key('formulario_unica_vivienda_field')), findsOneWidget);
    });

    testWidgets('FormularioSolicitudScreen does not render VIS fields for regular credit', (tester) async {
      _setLargeSurface(tester);

      const regularProduct = ProductoCreditoSocio(
        id: 2,
        codigo: 'CONS-01',
        nombre: 'Crédito de Consumo',
        moneda: 'BOB',
        montoMin: '1000.00',
        montoMax: '50000.00',
        plazoMinMeses: 6,
        plazoMaxMeses: 36,
        tasaInteresAnual: '18.00',
        tipoAmortizacion: 'FRANCES',
        requiereGarantia: false,
        tipoCreditoAsfi: 'CONSUMO',
      );

      await tester.pumpWidget(_wrap(const FormularioSolicitudScreen(
        producto: regularProduct,
        monto: '5000.00',
        plazoMeses: 12,
        cuotaEstimada: '458.00',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Vivienda de Interés Social (VIS)'), findsNothing);
      expect(find.byKey(const Key('formulario_valor_vivienda_field')), findsNothing);
    });

    testWidgets('ReclamosScreen displays claims, SLA breach warning and handles conformity', (tester) async {
      _setLargeSurface(tester);

      final fake = FakeNormativaService();
      fake.claimsResponse = [
        const ReclamoItem(
          id: 1,
          numeroReclamo: 'PR-2026-000001',
          socioId: 1,
          socio: 'Socio Test',
          tipo: 'COBRO_INDEBIDO',
          descripcion: 'Cobro de comisión no pactada',
          canal: 'MOVIL',
          estado: 'RESPONDIDO',
          fechaRegistro: '2026-11-10T08:00:00',
          fechaLimiteRespuesta: '2026-11-17T08:00:00',
          vencido: false,
          respuesta: 'Se revertirá el monto de Bs. 50.',
          procedente: true,
          fechaRespuesta: '2026-11-15T10:00:00',
        ),
        const ReclamoItem(
          id: 2,
          numeroReclamo: 'PR-2026-000002',
          socioId: 1,
          socio: 'Socio Test',
          tipo: 'ATENCION',
          descripcion: 'Mala atención en plataforma',
          canal: 'MOVIL',
          estado: 'EN_ATENCION',
          fechaRegistro: '2026-11-01T08:00:00',
          fechaLimiteRespuesta: '2026-11-08T08:00:00',
          vencido: true,
        ),
      ];

      await tester.pumpWidget(_wrap(ReclamosScreen(service: fake)));
      await tester.pumpAndSettle();

      expect(find.text('PR-2026-000001'), findsOneWidget);
      expect(find.text('PR-2026-000002'), findsOneWidget);
      expect(find.textContaining('Cobro Indebido'), findsOneWidget);
      expect(find.text('Plazo legal vencido (> 5 días hábiles sin respuesta)'), findsOneWidget);
      expect(find.text('Respuesta de la Entidad'), findsOneWidget);
      expect(find.text('PROCEDENTE'), findsOneWidget);

      // Verify "Conforme" button
      final conformeBtn = find.byKey(const Key('reclamo_conforme_btn_1'));
      expect(conformeBtn, findsOneWidget);
      await tester.tap(conformeBtn);
      await tester.pumpAndSettle();

      expect(find.text('Aceptar Conformidad'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmar_conformidad_btn')));
      await tester.pumpAndSettle();

      expect(fake.registerConformityCalls, 1);
      expect(fake.lastConforme, isTrue);
    });

    testWidgets('ReprogramacionScreen displays history and request dialog', (tester) async {
      _setLargeSurface(tester);

      final fake = FakeNormativaService();
      fake.reschedulingResponse = [
        const ReprogramacionCreditoItem(
          id: 10,
          creditoId: 1,
          numeroCredito: 'CR-100',
          estado: 'APROBADA',
          canal: 'MOVIL',
          motivo: 'Afectación de ingresos',
          nuevoPlazoMeses: 24,
          saldoCapital: '45000.00',
          interesDiferido: '500.00',
          cuotasReprogramadas: 2,
          fechaSolicitud: '2026-11-10T10:00:00',
          fechaResolucion: '2026-11-12T10:00:00',
        ),
      ];

      await tester.pumpWidget(_wrap(ReprogramacionScreen(
        creditId: 1,
        credit: const SocioCredit(
          id: 1,
          number: 'CR-100',
          product: 'Vivienda Social',
          currency: 'BOB',
          disbursedAmount: '50000.00',
          outstandingBalance: '45000.00',
          status: 'VIGENTE',
          nextInstallment: null,
        ),
        service: fake,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Solicitud #10'), findsOneWidget);
      expect(find.text('APROBADA'), findsOneWidget);
      expect(find.text('Nuevo plazo solicitado: 24 meses'), findsOneWidget);
      expect(find.text('Interés diferido (1° cuota): Bs. 500.00'), findsOneWidget);

      // Tap on Nueva Solicitud
      final newBtn = find.byKey(const Key('solicitar_reprogramacion_btn'));
      expect(newBtn, findsOneWidget);
      await tester.tap(newBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reprogramacion_plazo_field')), findsOneWidget);
      expect(find.byKey(const Key('reprogramacion_motivo_field')), findsOneWidget);
    });

    testWidgets('CronogramaCreditoScreen displays TEA, TEAC and REPROGRAMADA installment badge', (tester) async {
      _setLargeSurface(tester);

      final fake = FakeNormativaService();
      fake.scheduleResponse = const CreditSchedule(
        credit: {
          'id': 1,
          'numero_credito': 'CR-100',
          'moneda': 'BOB',
          'saldo_pendiente': '45000.00',
          'producto': 'Vivienda Social',
          'estado': 'VIGENTE',
        },
        installments: [
          CreditScheduleItem(
            number: 1,
            dueDate: '2026-10-15',
            capital: '1000.00',
            interest: '200.00',
            insurance: '50.00',
            totalAmount: '1250.00',
            capitalBalance: '44000.00',
            status: 'REPROGRAMADA',
            paymentDate: '',
          ),
          CreditScheduleItem(
            number: 2,
            dueDate: '2026-11-15',
            capital: '1000.00',
            interest: '200.00',
            insurance: '50.00',
            totalAmount: '1250.00',
            capitalBalance: '43000.00',
            status: 'PENDIENTE',
            paymentDate: '',
          ),
        ],
        totalInsurance: '100.00',
        tea: '5.50',
        teac: '6.05',
      );

      await tester.pumpWidget(_wrap(CronogramaCreditoScreen(
        creditId: 1,
        credit: const SocioCredit(
          id: 1,
          number: 'CR-100',
          product: 'Vivienda Social',
          currency: 'BOB',
          disbursedAmount: '50000.00',
          outstandingBalance: '45000.00',
          status: 'VIGENTE',
          nextInstallment: null,
        ),
        service: fake,
      )));
      await tester.pumpAndSettle();

      expect(find.text('5.50%'), findsOneWidget);
      expect(find.text('6.05%'), findsOneWidget);
      expect(find.text('TEA'), findsOneWidget);
      expect(find.text('TEAC'), findsOneWidget);
      expect(find.text('REPROGRAMADA'), findsWidgets);
      expect(find.text('Cuota reprogramada'), findsOneWidget);
    });
  });
}
