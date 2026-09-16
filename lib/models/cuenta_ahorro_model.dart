// Modelo de cuenta de ahorro del backend SI2.
//
// Respuesta real: GET /api/v1/ahorros/mis-cuentas
// {"id":int,"numero":str,"tipo_producto":str,"saldo_disponible":number,
//  "saldo_bloqueado":number,"estado":str,"fecha_registro":"YYYY-MM-DD",
//  "socio_id":int,"moneda":{"id":int,"codigo_iso":str,"nombre":str,"simbolo":str}}
//
// Los campos numéricos toleran int / double / string porque el backend
// puede serializar decimales de distintas formas.

// Currency nested inside the savings account payload.
class Moneda {
  final int id;
  final String currencyCode;
  final String name;
  final String symbol;

  const Moneda({
    required this.id,
    required this.currencyCode,
    required this.name,
    required this.symbol,
  });

  factory Moneda.fromJson(Map<String, dynamic> json) {
    return Moneda(
      id: _toInt(json['id']),
      currencyCode: json['codigo_iso']?.toString() ?? '',
      name: json['nombre']?.toString() ?? '',
      symbol: json['simbolo']?.toString() ?? '',
    );
  }
}

// Savings account owned by the authenticated socio.
class CuentaAhorro {
  final int id;
  final String accountNumber;
  final String productType;
  final double availableBalance;
  final double blockedBalance;
  final String status;
  final String registrationDate;
  final int socioId;
  final Moneda currency;

  const CuentaAhorro({
    required this.id,
    required this.accountNumber,
    required this.productType,
    required this.availableBalance,
    required this.blockedBalance,
    required this.status,
    required this.registrationDate,
    required this.socioId,
    required this.currency,
  });

  factory CuentaAhorro.fromJson(Map<String, dynamic> json) {
    final monedaJson = json['moneda'];
    return CuentaAhorro(
      id: _toInt(json['id']),
      accountNumber: json['numero']?.toString() ?? '',
      productType: json['tipo_producto']?.toString() ?? '',
      availableBalance: _toDouble(json['saldo_disponible']),
      blockedBalance: _toDouble(json['saldo_bloqueado']),
      status: json['estado']?.toString() ?? '',
      registrationDate: json['fecha_registro']?.toString() ?? '',
      socioId: _toInt(json['socio_id']),
      currency: monedaJson is Map<String, dynamic>
          ? Moneda.fromJson(monedaJson)
          : const Moneda(id: 0, currencyCode: '', name: '', symbol: ''),
    );
  }

  /// Formato corto para UI: "Bs 1,250.50".
  String get formattedAvailable =>
      '${currency.symbol} ${availableBalance.toStringAsFixed(2)}';

  String get formattedBlocked =>
      '${currency.symbol} ${blockedBalance.toStringAsFixed(2)}';
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
