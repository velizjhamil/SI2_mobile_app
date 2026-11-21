/// Modelo para el feedback y calificación de servicios (CRM).
class EncuestaFeedback {
  final int id;
  final String servicio;
  final int calificacion;
  final int? recomendaria;
  final String? comentario;
  final String canal;
  final DateTime? fecha;

  const EncuestaFeedback({
    required this.id,
    required this.servicio,
    required this.calificacion,
    this.recomendaria,
    this.comentario,
    required this.canal,
    this.fecha,
  });

  factory EncuestaFeedback.fromJson(Map<String, dynamic> json) {
    return EncuestaFeedback(
      id: (json['id'] as num?)?.toInt() ?? 0,
      servicio: json['servicio']?.toString() ?? 'OTRO',
      calificacion: (json['calificacion'] as num?)?.toInt() ?? 5,
      recomendaria: (json['recomendaria'] as num?)?.toInt(),
      comentario: json['comentario']?.toString(),
      canal: json['canal']?.toString() ?? 'MOVIL',
      fecha: json['fecha'] != null
          ? DateTime.tryParse(json['fecha'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'servicio': servicio,
      'calificacion': calificacion,
      if (recomendaria != null) 'recomendaria': recomendaria,
      if (comentario != null) 'comentario': comentario,
      'canal': canal,
      if (fecha != null) 'fecha': fecha!.toIso8601String(),
    };
  }

  String get servicioLabel {
    switch (servicio) {
      case 'CREDITO':
        return 'Crédito';
      case 'AHORRO':
        return 'Ahorro';
      case 'CAJA':
        return 'Caja y Ventanilla';
      case 'ATENCION':
        return 'Atención al Cliente';
      case 'APP_MOVIL':
        return 'Banca Móvil';
      case 'OTRO':
      default:
        return 'Otro';
    }
  }

  String get calificacionLabel {
    switch (calificacion) {
      case 1:
        return 'Muy insatisfecho';
      case 2:
        return 'Insatisfecho';
      case 3:
        return 'Neutral';
      case 4:
        return 'Satisfecho';
      case 5:
        return 'Excelente';
      default:
        return '$calificacion estrellas';
    }
  }
}
