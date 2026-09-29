String _string(dynamic value) => value?.toString() ?? '';
int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;

class SolicitudResumenCampo {
  final int id;
  final String numeroSolicitud;
  final String fechaSolicitud;
  final String? fechaActualizacion;
  final String estado;
  final String socioNombre;
  final String socioCi;
  final String productoNombre;
  final String monedaSimbolo;
  final String monto;
  final int plazoMeses;
  final String destino;
  final String? destinoDetalle;
  final String canalOrigen;
  final bool requiereEvaluacion;
  final EvaluacionCampoExistente? evaluacion;
  final String? ultimaEvaluacionDictamen;
  final int? ultimaEvaluacionScore;

  const SolicitudResumenCampo({
    required this.id,
    required this.numeroSolicitud,
    required this.fechaSolicitud,
    this.fechaActualizacion,
    required this.estado,
    required this.socioNombre,
    required this.socioCi,
    required this.productoNombre,
    required this.monedaSimbolo,
    required this.monto,
    required this.plazoMeses,
    required this.destino,
    this.destinoDetalle,
    required this.canalOrigen,
    required this.requiereEvaluacion,
    this.evaluacion,
    this.ultimaEvaluacionDictamen,
    this.ultimaEvaluacionScore,
  });

  factory SolicitudResumenCampo.fromJson(Map<String, dynamic> json) {
    final socioMap = json['socio'] as Map? ?? {};
    final prodMap = json['producto'] as Map? ?? {};
    final monMap = json['moneda'] as Map? ?? {};
    final evalMap = json['evaluacion'] as Map?;
    final ultEvalMap = json['ultima_evaluacion'] as Map?;

    return SolicitudResumenCampo(
      id: _int(json['id']),
      numeroSolicitud: _string(json['numero_solicitud']),
      fechaSolicitud: _string(json['fecha_solicitud']),
      fechaActualizacion: json['fecha_actualizacion']?.toString(),
      estado: _string(json['estado']),
      socioNombre: _string(socioMap['nombre_completo']),
      socioCi: _string(socioMap['ci']),
      productoNombre: _string(prodMap['nombre']),
      monedaSimbolo: _string(monMap['simbolo']),
      monto: _string(json['monto']),
      plazoMeses: _int(json['plazo_meses']),
      destino: _string(json['destino']),
      destinoDetalle: json['destino_detalle']?.toString(),
      canalOrigen: _string(json['canal_origen']),
      requiereEvaluacion: json['requiere_evaluacion'] == true,
      evaluacion: evalMap != null
          ? EvaluacionCampoExistente.fromJson(evalMap.cast<String, dynamic>())
          : null,
      ultimaEvaluacionDictamen: ultEvalMap?['dictamen']?.toString(),
      ultimaEvaluacionScore: ultEvalMap != null ? _int(ultEvalMap['score']) : null,
    );
  }
}

class FichaCampoSolicitud {
  final int id;
  final String numeroSolicitud;
  final String producto;
  final String monto;
  final int plazoMeses;
  final String destino;
  final String? destinoDetalle;
  final String estado;
  final String canalOrigen;
  final bool requiereEvaluacion;

  const FichaCampoSolicitud({
    required this.id,
    required this.numeroSolicitud,
    required this.producto,
    required this.monto,
    required this.plazoMeses,
    required this.destino,
    this.destinoDetalle,
    required this.estado,
    required this.canalOrigen,
    required this.requiereEvaluacion,
  });

  factory FichaCampoSolicitud.fromJson(Map<String, dynamic> json) =>
      FichaCampoSolicitud(
        id: _int(json['id']),
        numeroSolicitud: _string(json['numero_solicitud']),
        producto: _string(json['producto']),
        monto: _string(json['monto']),
        plazoMeses: _int(json['plazo_meses']),
        destino: _string(json['destino']),
        destinoDetalle: json['destino_detalle']?.toString(),
        estado: _string(json['estado']),
        canalOrigen: _string(json['canal_origen']),
        requiereEvaluacion: json['requiere_evaluacion'] == true,
      );
}

class FichaCampoSocio {
  final int id;
  final String nombreCompleto;
  final String ci;
  final String? telefono;
  final String? direccion;

  const FichaCampoSocio({
    required this.id,
    required this.nombreCompleto,
    required this.ci,
    this.telefono,
    this.direccion,
  });

  String get telefonoDisplay =>
      telefono != null && telefono!.trim().isNotEmpty ? telefono! : '—';
  String get direccionDisplay =>
      direccion != null && direccion!.trim().isNotEmpty ? direccion! : '—';

  factory FichaCampoSocio.fromJson(Map<String, dynamic> json) =>
      FichaCampoSocio(
        id: _int(json['id']),
        nombreCompleto: _string(json['nombre_completo']),
        ci: _string(json['ci']),
        telefono: json['telefono']?.toString(),
        direccion: json['direccion']?.toString(),
      );
}

class FichaCampoDatosDeclarados {
  final String? ingresoMensual;
  final String? egresoMensual;
  final String? actividadEconomica;
  final String? fuenteIngresos;

  const FichaCampoDatosDeclarados({
    this.ingresoMensual,
    this.egresoMensual,
    this.actividadEconomica,
    this.fuenteIngresos,
  });

  factory FichaCampoDatosDeclarados.fromJson(Map<String, dynamic> json) =>
      FichaCampoDatosDeclarados(
        ingresoMensual: json['ingreso_mensual']?.toString(),
        egresoMensual: json['egreso_mensual']?.toString(),
        actividadEconomica: json['actividad_economica']?.toString(),
        fuenteIngresos: json['fuente_ingresos']?.toString(),
      );
}

class EvaluacionCampoExistente {
  final int? id;
  final String ingresoMensual;
  final String egresoMensual;
  final String cuotaDeudasMensual;
  final String? capacidadPago;
  final String actividadEconomica;
  final String fuenteIngresos;
  final int antiguedadLaboralMeses;
  final String calificacionAsfi;
  final String? coordenadas;
  final String? observaciones;
  final String? fecha;

  const EvaluacionCampoExistente({
    this.id,
    required this.ingresoMensual,
    required this.egresoMensual,
    required this.cuotaDeudasMensual,
    this.capacidadPago,
    required this.actividadEconomica,
    required this.fuenteIngresos,
    required this.antiguedadLaboralMeses,
    required this.calificacionAsfi,
    this.coordenadas,
    this.observaciones,
    this.fecha,
  });

  factory EvaluacionCampoExistente.fromJson(Map<String, dynamic> json) =>
      EvaluacionCampoExistente(
        id: json['id'] != null ? _int(json['id']) : null,
        ingresoMensual: _string(json['ingreso_mensual']),
        egresoMensual: _string(json['egreso_mensual']),
        cuotaDeudasMensual: _string(json['cuota_deudas_mensual']),
        capacidadPago: json['capacidad_pago']?.toString(),
        actividadEconomica: _string(json['actividad_economica']),
        fuenteIngresos: _string(json['fuente_ingresos']),
        antiguedadLaboralMeses: _int(json['antiguedad_laboral_meses']),
        calificacionAsfi: _string(json['calificacion_asfi']),
        coordenadas: json['coordenadas']?.toString(),
        observaciones: json['observaciones']?.toString(),
        fecha: json['fecha']?.toString(),
      );
}

class CatalogosFichaCampo {
  final List<String> fuentesIngresos;
  final List<String> calificacionesAsfi;

  const CatalogosFichaCampo({
    this.fuentesIngresos = const ['DEPENDIENTE', 'INDEPENDIENTE', 'MIXTO'],
    this.calificacionesAsfi = const ['A', 'B', 'C', 'D', 'E', 'F'],
  });

  factory CatalogosFichaCampo.fromJson(Map<String, dynamic> json) =>
      CatalogosFichaCampo(
        fuentesIngresos: (json['fuentes_ingresos'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        calificacionesAsfi: (json['calificaciones_asfi'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class FichaCampo {
  final FichaCampoSolicitud solicitud;
  final FichaCampoSocio socio;
  final FichaCampoDatosDeclarados? datosDeclarados;
  final EvaluacionCampoExistente? evaluacion;
  final CatalogosFichaCampo catalogos;

  const FichaCampo({
    required this.solicitud,
    required this.socio,
    this.datosDeclarados,
    this.evaluacion,
    this.catalogos = const CatalogosFichaCampo(),
  });

  factory FichaCampo.fromJson(Map<String, dynamic> json) {
    final solMap = json['solicitud'] as Map? ?? {};
    final socioMap = json['socio'] as Map? ?? {};
    final declMap = json['datos_declarados'] as Map?;
    final evalMap = json['evaluacion'] as Map?;
    final catMap = json['catalogos'] as Map? ?? {};

    return FichaCampo(
      solicitud: FichaCampoSolicitud.fromJson(solMap.cast<String, dynamic>()),
      socio: FichaCampoSocio.fromJson(socioMap.cast<String, dynamic>()),
      datosDeclarados: declMap != null
          ? FichaCampoDatosDeclarados.fromJson(declMap.cast<String, dynamic>())
          : null,
      evaluacion: evalMap != null
          ? EvaluacionCampoExistente.fromJson(evalMap.cast<String, dynamic>())
          : null,
      catalogos: CatalogosFichaCampo.fromJson(catMap.cast<String, dynamic>()),
    );
  }
}

class EvaluacionCampoForm {
  final String ingresoMensual;
  final String egresoMensual;
  final String cuotaDeudasMensual;
  final String actividadEconomica;
  final String fuenteIngresos;
  final int antiguedadLaboralMeses;
  final String calificacionAsfi;
  final String? observaciones;

  const EvaluacionCampoForm({
    required this.ingresoMensual,
    required this.egresoMensual,
    required this.cuotaDeudasMensual,
    required this.actividadEconomica,
    required this.fuenteIngresos,
    required this.antiguedadLaboralMeses,
    required this.calificacionAsfi,
    this.observaciones,
  });

  Map<String, dynamic> toJson() => {
        'evaluacion': {
          'ingreso_mensual': ingresoMensual,
          'egreso_mensual': egresoMensual,
          'cuota_deudas_mensual': cuotaDeudasMensual,
          'actividad_economica': actividadEconomica,
          'fuente_ingresos': fuenteIngresos,
          'antiguedad_laboral_meses': antiguedadLaboralMeses,
          'calificacion_asfi': calificacionAsfi,
          if (observaciones != null && observaciones!.trim().isNotEmpty)
            'observaciones': observaciones!.trim(),
        }
      };
}

class ScoringFactor {
  final String codigo;
  final String descripcion;
  final int puntos;
  final int maximo;
  final String valor;
  final String motivo;

  const ScoringFactor({
    required this.codigo,
    required this.descripcion,
    required this.puntos,
    required this.maximo,
    required this.valor,
    required this.motivo,
  });

  factory ScoringFactor.fromJson(Map<String, dynamic> json) => ScoringFactor(
        codigo: _string(json['codigo']),
        descripcion: _string(json['descripcion']),
        puntos: _int(json['puntos']),
        maximo: _int(json['maximo']),
        valor: _string(json['valor']),
        motivo: _string(json['motivo']),
      );
}

class ScoringResultado {
  final int id;
  final int solicitudId;
  final int score;
  final String dictamen;
  final List<ScoringFactor> factores;
  final String? explicacion;
  final String? cuotaEstimada;
  final String? relacionCuotaIngreso;

  const ScoringResultado({
    required this.id,
    required this.solicitudId,
    required this.score,
    required this.dictamen,
    required this.factores,
    this.explicacion,
    this.cuotaEstimada,
    this.relacionCuotaIngreso,
  });

  bool get isAprobado => dictamen.toUpperCase() == 'APROBADO';
  bool get isRechazado => dictamen.toUpperCase() == 'RECHAZADO';
  bool get isObservado => dictamen.toUpperCase() == 'OBSERVADO';

  factory ScoringResultado.fromJson(Map<String, dynamic> json) =>
      ScoringResultado(
        id: _int(json['id']),
        solicitudId: _int(json['solicitud_id']),
        score: _int(json['score']),
        dictamen: _string(json['dictamen']),
        factores: (json['factores'] as List? ?? [])
            .whereType<Map>()
            .map((e) => ScoringFactor.fromJson(e.cast<String, dynamic>()))
            .toList(),
        explicacion: json['explicacion']?.toString(),
        cuotaEstimada: json['cuota_estimada']?.toString(),
        relacionCuotaIngreso: json['relacion_cuota_ingreso']?.toString(),
      );
}
