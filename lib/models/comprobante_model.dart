class Comprobante {
  final int id;
  final String number;
  final String type;
  final String channel;
  final String amount;
  final String currency;
  final String sourceAccount;
  final String? destinationAccount;
  final int? creditId;
  final int? installmentNumber;
  final String? description;
  final DateTime? issuedAt;
  final String verificationCode;
  final String verificationUrl;

  const Comprobante({
    required this.id,
    required this.number,
    required this.type,
    required this.channel,
    required this.amount,
    required this.currency,
    required this.sourceAccount,
    required this.destinationAccount,
    required this.creditId,
    required this.installmentNumber,
    required this.description,
    required this.issuedAt,
    required this.verificationCode,
    required this.verificationUrl,
  });

  factory Comprobante.fromJson(Map<String, dynamic> json) => Comprobante(
        id: _int(json['id']),
        number: _string(json['numero']),
        type: _string(json['tipo']),
        channel: _string(json['canal']),
        amount: _string(json['monto']),
        currency: _string(json['moneda']),
        sourceAccount: _string(json['cuenta_origen']),
        destinationAccount: json['cuenta_destino']?.toString(),
        creditId: _nullableInt(json['credito_id']),
        installmentNumber: _nullableInt(json['numero_cuota']),
        description: json['glosa']?.toString(),
        issuedAt: DateTime.tryParse(_string(json['emitido_en'])),
        verificationCode: _string(json['codigo_verificacion']),
        verificationUrl: _string(json['url_verificacion']),
      );
}

String _string(dynamic value) => value?.toString() ?? '';
int _int(dynamic value) => value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;
int? _nullableInt(dynamic value) => value == null ? null : _int(value);
