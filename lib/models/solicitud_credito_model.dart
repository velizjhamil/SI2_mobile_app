String _string(dynamic value) => value?.toString() ?? '';
int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;

class ProductoCreditoSocio {
  final int id;
  final String codigo;
  final String nombre;
  final String moneda;
  final String montoMin;
  final String montoMax;
  final int plazoMinMeses;
  final int plazoMaxMeses;
  final String tasaInteresAnual;
  final String tipoAmortizacion;
  final bool requiereGarantia;

  const ProductoCreditoSocio({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.moneda,
    required this.montoMin,
    required this.montoMax,
    required this.plazoMinMeses,
    required this.plazoMaxMeses,
    required this.tasaInteresAnual,
    required this.tipoAmortizacion,
    required this.requiereGarantia,
  });

  factory ProductoCreditoSocio.fromJson(Map<String, dynamic> json) =>
      ProductoCreditoSocio(
        id: _int(json['id']),
        codigo: _string(json['codigo']),
        nombre: _string(json['nombre']),
        moneda: _string(json['moneda']),
        montoMin: _string(json['monto_min']),
        montoMax: _string(json['monto_max']),
        plazoMinMeses: _int(json['plazo_min_meses']),
        plazoMaxMeses: _int(json['plazo_max_meses']),
        tasaInteresAnual: _string(json['tasa_interes_anual']),
        tipoAmortizacion: _string(json['tipo_amortizacion']),
        requiereGarantia: json['requiere_garantia'] == true,
      );
}

class SimulacionCuota {
  final int numero;
  final String capital;
  final String interes;
  final String cuota;
  final String saldo;

  const SimulacionCuota({
    required this.numero,
    required this.capital,
    required this.interes,
    required this.cuota,
    required this.saldo,
  });

  factory SimulacionCuota.fromJson(Map<String, dynamic> json) =>
      SimulacionCuota(
        numero: _int(json['numero']),
        capital: _string(json['capital']),
        interes: _string(json['interes']),
        cuota: _string(json['cuota']),
        saldo: _string(json['saldo']),
      );
}

class SimulacionCredito {
  final String cuotaEstimada;
  final String totalIntereses;
  final String totalAPagar;
  final List<SimulacionCuota> cronograma;

  const SimulacionCredito({
    required this.cuotaEstimada,
    required this.totalIntereses,
    required this.totalAPagar,
    required this.cronograma,
  });

  factory SimulacionCredito.fromJson(Map<String, dynamic> json) =>
      SimulacionCredito(
        cuotaEstimada: _string(json['cuota_estimada']),
        totalIntereses: _string(json['total_intereses']),
        totalAPagar: _string(json['total_a_pagar']),
        cronograma: (json['cronograma'] as List? ?? [])
            .whereType<Map>()
            .map((e) => SimulacionCuota.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

class DatosDeclarados {
  final String ingresoMensual;
  final String egresoMensual;
  final String actividadEconomica;
  final String fuenteIngresos;

  const DatosDeclarados({
    required this.ingresoMensual,
    required this.egresoMensual,
    required this.actividadEconomica,
    required this.fuenteIngresos,
  });

  Map<String, dynamic> toJson() => {
        'ingreso_mensual': ingresoMensual,
        'egreso_mensual': egresoMensual,
        'actividad_economica': actividadEconomica,
        'fuente_ingresos': fuenteIngresos,
      };

  factory DatosDeclarados.fromJson(Map<String, dynamic> json) =>
      DatosDeclarados(
        ingresoMensual: _string(json['ingreso_mensual']),
        egresoMensual: _string(json['egreso_mensual']),
        actividadEconomica: _string(json['actividad_economica']),
        fuenteIngresos: _string(json['fuente_ingresos']),
      );
}

class SolicitudCreditoItem {
  final int id;
  final String numeroSolicitud;
  final String producto;
  final String monto;
  final int plazoMeses;
  final String destino;
  final String estado;
  final String canalOrigen;
  final String fechaSolicitud;
  final bool requiereEvaluacion;
  final String? motivo;

  const SolicitudCreditoItem({
    required this.id,
    required this.numeroSolicitud,
    required this.producto,
    required this.monto,
    required this.plazoMeses,
    required this.destino,
    required this.estado,
    required this.canalOrigen,
    required this.fechaSolicitud,
    required this.requiereEvaluacion,
    this.motivo,
  });

  bool get isPendiente => estado == 'PENDIENTE';
  bool get isAnulada => estado == 'ANULADA';
  bool get isRechazada => estado == 'RECHAZADA';
  bool get isAprobada => estado == 'APROBADA';
  bool get isDesembolsado => estado == 'DESEMBOLSADO';
  bool get canCancel => isPendiente && requiereEvaluacion;

  factory SolicitudCreditoItem.fromJson(Map<String, dynamic> json) =>
      SolicitudCreditoItem(
        id: _int(json['id']),
        numeroSolicitud: _string(json['numero_solicitud']),
        producto: _string(json['producto']),
        monto: _string(json['monto']),
        plazoMeses: _int(json['plazo_meses']),
        destino: _string(json['destino']),
        estado: _string(json['estado']),
        canalOrigen: _string(json['canal_origen']),
        fechaSolicitud: _string(json['fecha_solicitud']),
        requiereEvaluacion: json['requiere_evaluacion'] == true,
        motivo: json['motivo']?.toString(),
      );
}

class TimelineEvent {
  final String estado;
  final String fecha;
  final String? motivo;

  const TimelineEvent({
    required this.estado,
    required this.fecha,
    this.motivo,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
        estado: _string(json['estado']),
        fecha: _string(json['fecha']),
        motivo: json['motivo']?.toString(),
      );
}

class SolicitudCreditoDetalle {
  final int id;
  final String numeroSolicitud;
  final String producto;
  final String monto;
  final int plazoMeses;
  final String destino;
  final String estado;
  final String canalOrigen;
  final String fechaSolicitud;
  final bool requiereEvaluacion;
  final String? motivo;
  final List<TimelineEvent> lineaTiempo;

  const SolicitudCreditoDetalle({
    required this.id,
    required this.numeroSolicitud,
    required this.producto,
    required this.monto,
    required this.plazoMeses,
    required this.destino,
    required this.estado,
    required this.canalOrigen,
    required this.fechaSolicitud,
    required this.requiereEvaluacion,
    this.motivo,
    this.lineaTiempo = const [],
  });

  bool get isPendiente => estado == 'PENDIENTE';
  bool get canCancel => isPendiente && requiereEvaluacion;

  factory SolicitudCreditoDetalle.fromJson(Map<String, dynamic> json) =>
      SolicitudCreditoDetalle(
        id: _int(json['id']),
        numeroSolicitud: _string(json['numero_solicitud']),
        producto: _string(json['producto']),
        monto: _string(json['monto']),
        plazoMeses: _int(json['plazo_meses']),
        destino: _string(json['destino']),
        estado: _string(json['estado']),
        canalOrigen: _string(json['canal_origen']),
        fechaSolicitud: _string(json['fecha_solicitud']),
        requiereEvaluacion: json['requiere_evaluacion'] == true,
        motivo: json['motivo']?.toString(),
        lineaTiempo: (json['linea_tiempo'] as List? ?? [])
            .whereType<Map>()
            .map((e) => TimelineEvent.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}
