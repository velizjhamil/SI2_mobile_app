class ExtractoMovimiento {
  final int transactionId;
  final String date;
  final String type;
  final String description;
  final String channel;
  final String amount;
  final String direction;
  final String resultingBalance;

  const ExtractoMovimiento({
    required this.transactionId,
    required this.date,
    required this.type,
    required this.description,
    required this.channel,
    required this.amount,
    required this.direction,
    required this.resultingBalance,
  });

  factory ExtractoMovimiento.fromJson(Map<String, dynamic> json) =>
      ExtractoMovimiento(
        transactionId: _int(json['transaccion_id']),
        date: _string(json['fecha']),
        type: _string(json['tipo']),
        description: _string(json['descripcion']),
        channel: _string(json['canal']),
        amount: _string(json['monto']),
        direction: _string(json['sentido']),
        resultingBalance: _string(json['saldo_resultante']),
      );
}

class ExtractoCuenta {
  final Map<String, dynamic> account;
  final String from;
  final String to;
  final String openingBalance;
  final String totalCredits;
  final String totalDebits;
  final String closingBalance;
  final int total;
  final List<ExtractoMovimiento> movements;

  const ExtractoCuenta({
    required this.account,
    required this.from,
    required this.to,
    required this.openingBalance,
    required this.totalCredits,
    required this.totalDebits,
    required this.closingBalance,
    required this.total,
    required this.movements,
  });

  factory ExtractoCuenta.fromJson(Map<String, dynamic> json) => ExtractoCuenta(
        account: (json['cuenta'] as Map?)?.cast<String, dynamic>() ?? {},
        from: _string(json['desde']),
        to: _string(json['hasta']),
        openingBalance: _string(json['saldo_inicial']),
        totalCredits: _string(json['total_creditos']),
        totalDebits: _string(json['total_debitos']),
        closingBalance: _string(json['saldo_final']),
        total: _int(json['total']),
        movements: (json['movimientos'] as List? ?? [])
            .whereType<Map>()
            .map((item) =>
                ExtractoMovimiento.fromJson(item.cast<String, dynamic>()))
            .toList(),
      );
}

class CreditInstallment {
  final int number;
  final String dueDate;
  final String totalAmount;

  const CreditInstallment({
    required this.number,
    required this.dueDate,
    required this.totalAmount,
  });

  factory CreditInstallment.fromJson(Map<String, dynamic> json) =>
      CreditInstallment(
        number: _int(json['numero']),
        dueDate: _string(json['fecha_vencimiento']),
        totalAmount: _string(json['monto_total']),
      );
}

class SocioCredit {
  final int id;
  final String number;
  final String product;
  final String currency;
  final String disbursedAmount;
  final String outstandingBalance;
  final String status;
  final CreditInstallment? nextInstallment;

  const SocioCredit({
    required this.id,
    required this.number,
    required this.product,
    required this.currency,
    required this.disbursedAmount,
    required this.outstandingBalance,
    required this.status,
    required this.nextInstallment,
  });

  factory SocioCredit.fromJson(Map<String, dynamic> json) => SocioCredit(
        id: _int(json['id']),
        number: _string(json['numero_credito']),
        product: _string(json['producto']),
        currency: _string(json['moneda']),
        disbursedAmount: _string(json['monto_desembolsado']),
        outstandingBalance: _string(json['saldo_pendiente']),
        status: _string(json['estado']),
        nextInstallment: (json['proxima_cuota'] as Map?)
            ?.cast<String, dynamic>()
            .let(CreditInstallment.fromJson),
      );
}

class CreditPayment {
  final Map<String, dynamic> data;
  const CreditPayment(this.data);
}

class CreditScheduleItem {
  final int number;
  final String dueDate;
  final String capital;
  final String interest;
  final String insurance;
  final String totalAmount;
  final String capitalBalance;
  final String status;
  final String paymentDate;

  const CreditScheduleItem({
    required this.number,
    required this.dueDate,
    required this.capital,
    required this.interest,
    required this.insurance,
    required this.totalAmount,
    required this.capitalBalance,
    required this.status,
    required this.paymentDate,
  });

  factory CreditScheduleItem.fromJson(Map<String, dynamic> json) =>
      CreditScheduleItem(
        number: _int(json['numero']),
        dueDate: _string(json['fecha_vencimiento']),
        capital: _string(json['capital']),
        interest: _string(json['interes']),
        insurance: _string(json['seguro']),
        totalAmount: _string(json['monto_total']),
        capitalBalance: _string(json['saldo_capital']),
        status: _string(json['estado']),
        paymentDate: _string(json['fecha_pago']),
      );
}

class CreditSchedule {
  final Map<String, dynamic> credit;
  final List<CreditScheduleItem> installments;
  const CreditSchedule({required this.credit, required this.installments});

  factory CreditSchedule.fromJson(Map<String, dynamic> json) => CreditSchedule(
        credit: (json['credito'] as Map?)?.cast<String, dynamic>() ?? {},
        installments: (json['cuotas'] as List? ?? [])
            .whereType<Map>()
            .map((item) =>
                CreditScheduleItem.fromJson(item.cast<String, dynamic>()))
            .toList(),
      );
}

class Dpf {
  final int id;
  final String certificateNumber;
  final String currency;
  final String amount;
  final String interestRate;
  final int termDays;
  final String openingDate;
  final String maturityDate;
  final String status;
  final String paymentFrequency;
  final List<DpfScheduleItem> schedule;

  const Dpf({
    required this.id,
    required this.certificateNumber,
    required this.currency,
    required this.amount,
    required this.interestRate,
    required this.termDays,
    required this.openingDate,
    required this.maturityDate,
    required this.status,
    required this.paymentFrequency,
    this.schedule = const [],
  });

  factory Dpf.fromJson(Map<String, dynamic> json) => Dpf(
        id: _int(json['id']),
        certificateNumber: _string(json['numero_certificado']),
        currency: _string(json['moneda']),
        amount: _string(json['monto']),
        interestRate: _string(json['tasa_interes']),
        termDays: _int(json['plazo_dias']),
        openingDate: _string(json['fecha_apertura']),
        maturityDate: _string(json['fecha_vencimiento']),
        status: _string(json['estado']),
        paymentFrequency: _string(json['frecuencia_pago']),
        schedule: (json['cronograma'] as List? ?? [])
            .whereType<Map>()
            .map((item) =>
                DpfScheduleItem.fromJson(item.cast<String, dynamic>()))
            .toList(),
      );
}

class DpfScheduleItem {
  final int number;
  final String paymentDate;
  final String grossInterest;
  final String withholding;
  final String netInterest;
  final String status;
  final String actualPaymentDate;

  const DpfScheduleItem({
    required this.number,
    required this.paymentDate,
    required this.grossInterest,
    required this.withholding,
    required this.netInterest,
    required this.status,
    required this.actualPaymentDate,
  });

  factory DpfScheduleItem.fromJson(Map<String, dynamic> json) =>
      DpfScheduleItem(
        number: _int(json['numero']),
        paymentDate: _string(json['fecha_pago']),
        grossInterest: _string(json['interes_bruto']),
        withholding: _string(json['retencion_rciva']),
        netInterest: _string(json['interes_neto']),
        status: _string(json['estado']),
        actualPaymentDate: _string(json['fecha_pago_real']),
      );
}

class RecreditOffer {
  final Map<String, dynamic> data;
  final int id;
  final String amount;
  final int termMonths;

  const RecreditOffer({
    required this.data,
    required this.id,
    required this.amount,
    required this.termMonths,
  });

  factory RecreditOffer.fromJson(Map<String, dynamic> json) => RecreditOffer(
        data: json,
        id: _int(json['id']),
        amount: _string(json['monto']),
        termMonths: _int(json['plazo_meses']),
      );
}

String _string(dynamic value) => value?.toString() ?? '';
int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;

extension _NullableMap<T> on T? {
  R? let<R>(R Function(T value) transform) =>
      this == null ? null : transform(this as T);
}
