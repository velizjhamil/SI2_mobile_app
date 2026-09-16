// Modelo de transferencia entre cuentas propias del backend SI2.
//
// Respuesta real: POST /api/v1/ahorros/transferencias → 201
// {"transaccion_salida_id":int,"transaccion_entrada_id":int,
//  "cuenta_origen":{...CuentaAhorro},"cuenta_destino":{...CuentaAhorro},
//  "monto":number,"glosa":str|null,"fecha_hora":ISO datetime str}
//
// Los campos numéricos toleran int / double / string porque el backend
// puede serializar decimales de distintas formas.

import 'cuenta_ahorro_model.dart';

// Successful transfer between two accounts owned by the same socio.
class TransferenciaModel {
  final int transaccionSalidaId;
  final int transaccionEntradaId;
  final CuentaAhorro cuentaOrigen;
  final CuentaAhorro cuentaDestino;
  final double monto;
  final String? glosa;
  final String fechaHora;

  const TransferenciaModel({
    required this.transaccionSalidaId,
    required this.transaccionEntradaId,
    required this.cuentaOrigen,
    required this.cuentaDestino,
    required this.monto,
    required this.glosa,
    required this.fechaHora,
  });

  factory TransferenciaModel.fromJson(Map<String, dynamic> json) {
    final origenJson = json['cuenta_origen'];
    final destinoJson = json['cuenta_destino'];
    final glosaRaw = json['glosa'];
    return TransferenciaModel(
      transaccionSalidaId: _toInt(json['transaccion_salida_id']),
      transaccionEntradaId: _toInt(json['transaccion_entrada_id']),
      cuentaOrigen: origenJson is Map<String, dynamic>
          ? CuentaAhorro.fromJson(origenJson)
          : _emptyCuenta(),
      cuentaDestino: destinoJson is Map<String, dynamic>
          ? CuentaAhorro.fromJson(destinoJson)
          : _emptyCuenta(),
      monto: _toDouble(json['monto']),
      glosa: glosaRaw?.toString(),
      fechaHora: json['fecha_hora']?.toString() ?? '',
    );
  }
}

CuentaAhorro _emptyCuenta() {
  return const CuentaAhorro(
    id: 0,
    accountNumber: '',
    productType: '',
    availableBalance: 0.0,
    blockedBalance: 0.0,
    status: '',
    registrationDate: '',
    socioId: 0,
    currency: Moneda(id: 0, currencyCode: '', name: '', symbol: ''),
  );
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0.0;
  return 0.0;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}
