/// Modelo para el extracto de pagos y amortización del crédito (S3, S4).
library;

class ExtractoCreditoInfo {
  final int id;
  final String numeroCredito;
  final String producto;
  final String? tipoCredito;
  final String? tipoAmortizacion;
  final String moneda;
  final String estado;
  final String montoDesembolsado;
  final String saldoPendiente;
  final String? tasaInteresAnual;
  final String? tasaSeguroDesgravamen;
  final int plazoMeses;
  final String? fechaDesembolso;

  const ExtractoCreditoInfo({
    required this.id,
    required this.numeroCredito,
    required this.producto,
    this.tipoCredito,
    this.tipoAmortizacion,
    required this.moneda,
    required this.estado,
    required this.montoDesembolsado,
    required this.saldoPendiente,
    this.tasaInteresAnual,
    this.tasaSeguroDesgravamen,
    this.plazoMeses = 0,
    this.fechaDesembolso,
  });

  String get tipoCreditoLabel {
    switch (tipoCredito) {
      case 'CONSUMO':
        return 'Consumo';
      case 'MICROCREDITO':
        return 'Microcrédito';
      case 'MICROCREDITO_AGROPECUARIO':
        return 'Microcrédito agropecuario';
      case 'VIVIENDA_HIPOTECARIA':
        return 'Vivienda hipotecaria';
      case 'VIVIENDA_SIN_GARANTIA':
        return 'Vivienda sin garantía';
      default:
        return (tipoCredito != null && tipoCredito!.isNotEmpty)
            ? tipoCredito!
            : 'Sin clasificar';
    }
  }

  String get tipoAmortizacionLabel {
    final t = (tipoAmortizacion ?? '').toUpperCase();
    if (t.contains('FRANC')) return 'Francés';
    if (t.contains('ALEM')) return 'Alemán';
    return (tipoAmortizacion != null && tipoAmortizacion!.isNotEmpty)
        ? tipoAmortizacion!
        : 'Francés';
  }

  factory ExtractoCreditoInfo.fromJson(Map<String, dynamic> json) {
    return ExtractoCreditoInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      numeroCredito: json['numero_credito']?.toString() ?? '',
      producto: json['producto']?.toString() ?? 'Crédito',
      tipoCredito: json['tipo_credito']?.toString(),
      tipoAmortizacion: json['tipo_amortizacion']?.toString(),
      moneda: json['moneda']?.toString() ?? 'BOB',
      estado: json['estado']?.toString() ?? 'VIGENTE',
      montoDesembolsado: json['monto_desembolsado']?.toString() ?? '0.00',
      saldoPendiente: json['saldo_pendiente']?.toString() ?? '0.00',
      tasaInteresAnual: json['tasa_interes_anual']?.toString(),
      tasaSeguroDesgravamen: json['tasa_seguro_desgravamen']?.toString(),
      plazoMeses: (json['plazo_meses'] as num?)?.toInt() ?? 0,
      fechaDesembolso: json['fecha_desembolso']?.toString(),
    );
  }
}

class ExtractoPagoItem {
  final int id;
  final String? fecha;
  final String numeroRecibo;
  final int numeroCuota;
  final String? modalidad;
  final int diasAtraso;
  final String capital;
  final String interes;
  final String seguro;
  final String mora;
  final String total;

  const ExtractoPagoItem({
    required this.id,
    this.fecha,
    required this.numeroRecibo,
    required this.numeroCuota,
    this.modalidad,
    this.diasAtraso = 0,
    required this.capital,
    required this.interes,
    required this.seguro,
    required this.mora,
    required this.total,
  });

  factory ExtractoPagoItem.fromJson(Map<String, dynamic> json) {
    return ExtractoPagoItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fecha: json['fecha']?.toString(),
      numeroRecibo: json['numero_recibo']?.toString() ?? '',
      numeroCuota: (json['numero_cuota'] as num?)?.toInt() ?? 0,
      modalidad: json['modalidad']?.toString(),
      diasAtraso: (json['dias_atraso'] as num?)?.toInt() ?? 0,
      capital: json['capital']?.toString() ?? '0.00',
      interes: json['interes']?.toString() ?? '0.00',
      seguro: json['seguro']?.toString() ?? '0.00',
      mora: json['mora']?.toString() ?? '0.00',
      total: json['total']?.toString() ?? '0.00',
    );
  }
}

class ExtractoTotales {
  final String capital;
  final String interes;
  final String seguro;
  final String mora;
  final String total;
  final int pagos;

  const ExtractoTotales({
    required this.capital,
    required this.interes,
    required this.seguro,
    required this.mora,
    required this.total,
    required this.pagos,
  });

  factory ExtractoTotales.fromJson(Map<String, dynamic> json) {
    return ExtractoTotales(
      capital: json['capital']?.toString() ?? '0.00',
      interes: json['interes']?.toString() ?? '0.00',
      seguro: json['seguro']?.toString() ?? '0.00',
      mora: json['mora']?.toString() ?? '0.00',
      total: json['total']?.toString() ?? '0.00',
      pagos: (json['pagos'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExtractoResumen {
  final int cuotasTotal;
  final int cuotasPagadas;
  final int cuotasVencidas;
  final int cuotasPendientes;
  final String seguroProgramado;

  const ExtractoResumen({
    required this.cuotasTotal,
    required this.cuotasPagadas,
    required this.cuotasVencidas,
    required this.cuotasPendientes,
    required this.seguroProgramado,
  });

  factory ExtractoResumen.fromJson(Map<String, dynamic> json) {
    return ExtractoResumen(
      cuotasTotal: (json['cuotas_total'] as num?)?.toInt() ?? 0,
      cuotasPagadas: (json['cuotas_pagadas'] as num?)?.toInt() ?? 0,
      cuotasVencidas: (json['cuotas_vencidas'] as num?)?.toInt() ?? 0,
      cuotasPendientes: (json['cuotas_pendientes'] as num?)?.toInt() ?? 0,
      seguroProgramado: json['seguro_programado']?.toString() ?? '0.00',
    );
  }
}

class ExtractoCuotaItem {
  final int numero;
  final String fechaVencimiento;
  final String capital;
  final String interes;
  final String seguro;
  final String montoTotal;
  final String saldoCapital;
  final String estado;

  const ExtractoCuotaItem({
    required this.numero,
    required this.fechaVencimiento,
    required this.capital,
    required this.interes,
    required this.seguro,
    required this.montoTotal,
    required this.saldoCapital,
    required this.estado,
  });

  factory ExtractoCuotaItem.fromJson(Map<String, dynamic> json) {
    return ExtractoCuotaItem(
      numero: (json['numero'] as num?)?.toInt() ?? 0,
      fechaVencimiento: json['fecha_vencimiento']?.toString() ?? '',
      capital: json['capital']?.toString() ?? '0.00',
      interes: json['interes']?.toString() ?? '0.00',
      seguro: json['seguro']?.toString() ?? '0.00',
      montoTotal: json['monto_total']?.toString() ?? '0.00',
      saldoCapital: json['saldo_capital']?.toString() ?? '0.00',
      estado: json['estado']?.toString() ?? 'PENDIENTE',
    );
  }
}

class ExtractoCredito {
  final ExtractoCreditoInfo credito;
  final String desde;
  final String hasta;
  final List<ExtractoPagoItem> pagos;
  final ExtractoTotales totales;
  final ExtractoResumen resumen;
  final List<ExtractoCuotaItem> cuotas;

  const ExtractoCredito({
    required this.credito,
    required this.desde,
    required this.hasta,
    required this.pagos,
    required this.totales,
    required this.resumen,
    required this.cuotas,
  });

  factory ExtractoCredito.fromJson(Map<String, dynamic> json) {
    return ExtractoCredito(
      credito: ExtractoCreditoInfo.fromJson(
          (json['credito'] as Map?)?.cast<String, dynamic>() ?? {}),
      desde: json['desde']?.toString() ?? '',
      hasta: json['hasta']?.toString() ?? '',
      pagos: (json['pagos'] as List? ?? [])
          .whereType<Map>()
          .map((item) => ExtractoPagoItem.fromJson(item.cast<String, dynamic>()))
          .toList(),
      totales: ExtractoTotales.fromJson(
          (json['totales'] as Map?)?.cast<String, dynamic>() ?? {}),
      resumen: ExtractoResumen.fromJson(
          (json['resumen'] as Map?)?.cast<String, dynamic>() ?? {}),
      cuotas: (json['cuotas'] as List? ?? [])
          .whereType<Map>()
          .map((item) => ExtractoCuotaItem.fromJson(item.cast<String, dynamic>()))
          .toList(),
    );
  }
}
