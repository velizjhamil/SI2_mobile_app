String _string(dynamic value) => value?.toString() ?? '';
int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;

class ReclamoItem {
  final int id;
  final String numeroReclamo;
  final int socioId;
  final String socio;
  final int? creditoId;
  final String tipo;
  final String descripcion;
  final String canal;
  final String estado;
  final String fechaRegistro;
  final String fechaLimiteRespuesta;
  final bool vencido;
  final int? usuarioAtencionId;
  final String? respuesta;
  final bool? procedente;
  final String? fechaRespuesta;
  final bool? conforme;
  final String? motivoDisconformidad;
  final String? fechaCierre;
  final String? fechaEscalamiento;
  final int ampliaciones;
  final String? motivoAmpliacion;
  final bool notificadoAsfi;

  const ReclamoItem({
    required this.id,
    required this.numeroReclamo,
    required this.socioId,
    required this.socio,
    this.creditoId,
    required this.tipo,
    required this.descripcion,
    required this.canal,
    required this.estado,
    required this.fechaRegistro,
    required this.fechaLimiteRespuesta,
    required this.vencido,
    this.usuarioAtencionId,
    this.respuesta,
    this.procedente,
    this.fechaRespuesta,
    this.conforme,
    this.motivoDisconformidad,
    this.fechaCierre,
    this.fechaEscalamiento,
    this.ampliaciones = 0,
    this.motivoAmpliacion,
    this.notificadoAsfi = false,
  });

  bool get isRegistrado => estado == 'REGISTRADO';
  bool get isEnAtencion => estado == 'EN_ATENCION';
  bool get isRespondido => estado == 'RESPONDIDO';
  bool get isCerrado => estado == 'CERRADO';
  bool get isEscaladoAsfi => estado == 'ESCALADO_ASFI';

  String get tipoLabel {
    switch (tipo.toUpperCase()) {
      case 'CREDITO':
        return 'Crédito';
      case 'AHORRO':
        return 'Cuentas de Ahorro';
      case 'CAJA':
        return 'Caja y Ventanilla';
      case 'COBRO_INDEBIDO':
        return 'Cobro Indebido';
      case 'ATENCION':
        return 'Atención al Cliente';
      case 'OTRO':
      default:
        return 'Otro';
    }
  }

  factory ReclamoItem.fromJson(Map<String, dynamic> json) => ReclamoItem(
        id: _int(json['id']),
        numeroReclamo: _string(json['numero_reclamo']),
        socioId: _int(json['socio_id']),
        socio: _string(json['socio']),
        creditoId: json['credito_id'] != null ? _int(json['credito_id']) : null,
        tipo: _string(json['tipo']),
        descripcion: _string(json['descripcion']),
        canal: _string(json['canal']),
        estado: _string(json['estado']),
        fechaRegistro: _string(json['fecha_registro']),
        fechaLimiteRespuesta: _string(json['fecha_limite_respuesta']),
        vencido: json['vencido'] == true,
        usuarioAtencionId: json['usuario_atencion_id'] != null
            ? _int(json['usuario_atencion_id'])
            : null,
        respuesta: json['respuesta']?.toString(),
        procedente:
            json['procedente'] is bool ? json['procedente'] as bool : null,
        fechaRespuesta: json['fecha_respuesta']?.toString(),
        conforme: json['conforme'] is bool ? json['conforme'] as bool : null,
        motivoDisconformidad: json['motivo_disconformidad']?.toString(),
        fechaCierre: json['fecha_cierre']?.toString(),
        fechaEscalamiento: json['fecha_escalamiento']?.toString(),
        ampliaciones: _int(json['ampliaciones']),
        motivoAmpliacion: json['motivo_ampliacion']?.toString(),
        notificadoAsfi: json['notificado_asfi'] == true,
      );
}
