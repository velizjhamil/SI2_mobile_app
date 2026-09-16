import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/cuenta_ahorro_model.dart';
import 'package:forest_microfinance/models/transferencia_model.dart';
import 'package:forest_microfinance/screens/transferencia_screen.dart';
import 'package:forest_microfinance/services/cuentas_service.dart';
import 'package:forest_microfinance/services/transferencias_service.dart';

Map<String, dynamic> _moneda({
  int id = 1,
  String codigo = 'BOB',
  String nombre = 'Boliviano',
  String simbolo = 'Bs',
}) {
  return {
    'id': id,
    'codigo_iso': codigo,
    'nombre': nombre,
    'simbolo': simbolo,
  };
}

Map<String, dynamic> _cuentaJson({
  required int id,
  required String numero,
  required String estado,
  required String codigoMoneda,
  required double disponible,
  String tipo = 'Ahorro Programado',
}) {
  return {
    'id': id,
    'numero': numero,
    'tipo_producto': tipo,
    'saldo_disponible': disponible,
    'saldo_bloqueado': 0,
    'estado': estado,
    'fecha_registro': '2026-03-01',
    'socio_id': 42,
    'moneda': _moneda(codigo: codigoMoneda),
  };
}

/// Tres cuentas BOB activas + una bloqueada + una en USD.
List<CuentaAhorro> _cuentasFake() {
  return [
    _cuentaJson(
        id: 7,
        numero: 'AH-000123',
        estado: 'ACTIVA',
        codigoMoneda: 'BOB',
        disponible: 1000.0),
    _cuentaJson(
        id: 8,
        numero: 'AH-000124',
        estado: 'ACTIVA',
        codigoMoneda: 'BOB',
        disponible: 500.0,
        tipo: 'Ahorro Libre'),
    _cuentaJson(
        id: 9,
        numero: 'AH-000125',
        estado: 'BLOQUEADA',
        codigoMoneda: 'BOB',
        disponible: 2000.0,
        tipo: 'Ahorro Infantil'),
    _cuentaJson(
        id: 10,
        numero: 'AH-000126',
        estado: 'ACTIVA',
        codigoMoneda: 'USD',
        disponible: 3000.0,
        tipo: 'Ahorro en Dólares'),
  ].map(CuentaAhorro.fromJson).toList();
}

class FakeCuentasService extends CuentasService {
  @override
  Future<CuentasResult> listarMisCuentas({http.Client? client}) async {
    return CuentasResult.success(_cuentasFake());
  }
}

class FakeTransferenciasService extends TransferenciasService {
  int llamadas = 0;
  int? lastOrigenId;
  int? lastDestinoId;
  double? lastMonto;
  String? lastGlosa;

  TransferenciaResult respuesta = TransferenciaResult.success(
    TransferenciaModel.fromJson({
      'transaccion_salida_id': 101,
      'transaccion_entrada_id': 102,
      'cuenta_origen': _cuentaJson(
          id: 7,
          numero: 'AH-000123',
          estado: 'ACTIVA',
          codigoMoneda: 'BOB',
          disponible: 900.0),
      'cuenta_destino': _cuentaJson(
          id: 8,
          numero: 'AH-000124',
          estado: 'ACTIVA',
          codigoMoneda: 'BOB',
          disponible: 600.0,
          tipo: 'Ahorro Libre'),
      'monto': 100.0,
      'glosa': null,
      'fecha_hora': '2026-09-15T10:30:00',
    }),
  );

  @override
  Future<TransferenciaResult> transferir({
    required int cuentaOrigenId,
    required int cuentaDestinoId,
    required double monto,
    String? glosa,
    http.Client? client,
  }) async {
    llamadas++;
    lastOrigenId = cuentaOrigenId;
    lastDestinoId = cuentaDestinoId;
    lastMonto = monto;
    lastGlosa = glosa;
    return respuesta;
  }
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(home: child),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeTransferenciasService transferencias,
) async {
  await tester.pumpWidget(_wrap(TransferenciaScreen(
    cuentasService: FakeCuentasService(),
    transferenciasService: transferencias,
  )));
  await tester.pumpAndSettle();
}

/// Selecciona el origen tocando su dropdown y eligiendo la cuenta indicada.
Future<void> _seleccionarOrigen(WidgetTester tester, String numero) async {
  await tester.tap(find.byKey(const Key('dropdown-origen')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(numero).last);
  await tester.pumpAndSettle();
}

/// Abre el dropdown de destino sin elegir (para inspeccionar sus opciones).
Future<void> _abrirDestino(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('dropdown-destino')));
  await tester.pumpAndSettle();
}

/// Completa origen + destino + monto válidos (sin confirmar el diálogo).
Future<void> _formularioValido(
  WidgetTester tester, {
  String monto = '100',
}) async {
  await _seleccionarOrigen(tester, 'AH-000123');
  await tester.tap(find.byKey(const Key('dropdown-destino')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('AH-000124').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('campo-monto')), monto);
  await tester.pump();
}

/// Toca "Transferir" y confirma el diálogo.
Future<void> _confirmar(WidgetTester tester) async {
  await tester.tap(find.text('Transferir'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirmar'));
  await tester.pumpAndSettle();
}

void main() {
  group('TransferenciaScreen (6.1)', () {
    testWidgets('el destino excluye el origen seleccionado', (tester) async {
      final transferencias = FakeTransferenciasService();
      await _pumpScreen(tester, transferencias);

      await _seleccionarOrigen(tester, 'AH-000123');
      await _abrirDestino(tester);

      // El origen solo aparece en su propio campo, nunca como opción destino.
      expect(find.textContaining('AH-000123'), findsOneWidget);
      // La otra cuenta BOB activa sí es opción destino.
      expect(find.textContaining('AH-000124'), findsWidgets);
    });

    testWidgets('el destino solo muestra ACTIVA con la misma moneda',
        (tester) async {
      final transferencias = FakeTransferenciasService();
      await _pumpScreen(tester, transferencias);

      await _seleccionarOrigen(tester, 'AH-000123');
      await _abrirDestino(tester);

      // Bloqueada (misma moneda) y USD (activa, otra moneda) quedan fuera.
      expect(find.textContaining('AH-000125'), findsNothing);
      expect(find.textContaining('AH-000126'), findsNothing);
    });

    testWidgets('monto vacío bloquea el envío sin llamar a transferir',
        (tester) async {
      final transferencias = FakeTransferenciasService();
      await _pumpScreen(tester, transferencias);

      await _seleccionarOrigen(tester, 'AH-000123');
      await tester.tap(find.byKey(const Key('dropdown-destino')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('AH-000124').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transferir'));
      await tester.pumpAndSettle();

      expect(find.text('Ingrese el monto.'), findsOneWidget);
      expect(transferencias.llamadas, 0);
      // Sin diálogo de confirmación.
      expect(find.text('Confirmar'), findsNothing);
    });

    testWidgets('monto cero o negativo bloquea el envío', (tester) async {
      for (final monto in ['0', '-50']) {
        final transferencias = FakeTransferenciasService();
        await _pumpScreen(tester, transferencias);
        await _formularioValido(tester, monto: monto);

        await tester.tap(find.text('Transferir'));
        await tester.pumpAndSettle();

        expect(find.text('El monto debe ser mayor a cero.'),
            findsOneWidget);
        expect(transferencias.llamadas, 0);
      }
    });

    testWidgets('monto mayor al saldo disponible bloquea el envío',
        (tester) async {
      final transferencias = FakeTransferenciasService();
      await _pumpScreen(tester, transferencias);
      // Origen AH-000123 con saldo 1000.
      await _formularioValido(tester, monto: '5000');

      await tester.tap(find.text('Transferir'));
      await tester.pumpAndSettle();

      expect(find.text('El monto supera el saldo disponible.'),
          findsOneWidget);
      expect(transferencias.llamadas, 0);
    });

    testWidgets('confirmar llama a transferir con ids y monto correctos',
        (tester) async {
      final transferencias = FakeTransferenciasService();
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => TransferenciaScreen(
                      cuentasService: FakeCuentasService(),
                      transferenciasService: transferencias,
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await _formularioValido(tester, monto: '100');
      await _confirmar(tester);

      expect(transferencias.llamadas, 1);
      expect(transferencias.lastOrigenId, 7);
      expect(transferencias.lastDestinoId, 8);
      expect(transferencias.lastMonto, 100.0);
      // Éxito: la pantalla se cierra con true.
      expect(find.byType(TransferenciaScreen), findsNothing);
    });

    testWidgets(
        'cambiar el origen invalida el destino elegido si ya no coincide '
        '(otra moneda)', (tester) async {
      final transferencias = FakeTransferenciasService();
      await _pumpScreen(tester, transferencias);

      await _seleccionarOrigen(tester, 'AH-000123'); // BOB
      await tester.tap(find.byKey(const Key('dropdown-destino')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('AH-000124').last); // BOB destino
      await tester.pumpAndSettle();

      // Cambiar el origen a la cuenta en USD invalida el destino BOB elegido.
      await _seleccionarOrigen(tester, 'AH-000126');

      // El campo destino vuelve al hint, no la cuenta vieja seleccionada.
      expect(find.text('Elija la cuenta destino'), findsOneWidget);

      await tester.tap(find.text('Transferir'));
      await tester.pumpAndSettle();

      expect(find.text('Seleccione la cuenta destino.'), findsOneWidget);
      expect(transferencias.llamadas, 0);
    });

    testWidgets(
        'doble-tap en Transferir no abre dos diálogos ni duplica la llamada',
        (tester) async {
      final transferencias = FakeTransferenciasService();
      await _pumpScreen(tester, transferencias);
      await _formularioValido(tester, monto: '100');

      // Dos taps consecutivos sin esperar a que se asiente el primero.
      await tester.tap(find.text('Transferir'));
      await tester.tap(find.text('Transferir'));
      await tester.pumpAndSettle();

      // Solo un diálogo de confirmación en pantalla, no dos apilados.
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(transferencias.llamadas, 1);
    });

    testWidgets('failure del servicio muestra el error en español',
        (tester) async {
      final transferencias = FakeTransferenciasService()
        ..respuesta = const TransferenciaResult.failure(
          'Saldo insuficiente para la transferencia.',
        );
      await _pumpScreen(tester, transferencias);
      await _formularioValido(tester, monto: '100');
      await _confirmar(tester);

      expect(transferencias.llamadas, 1);
      expect(find.text('Saldo insuficiente para la transferencia.'),
          findsOneWidget);
      // La pantalla sigue abierta para corregir.
      expect(find.byType(TransferenciaScreen), findsOneWidget);
    });
  });
}
