import 'campo_model.dart';

enum QueueItemKind {
  evaluationSave,
  photoUpload,
  photoDelete,
  prequalification,
}

class QueueItem {
  final String id;
  final QueueItemKind kind;
  final int? solicitudId;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  const QueueItem({
    required this.id,
    required this.kind,
    this.solicitudId,
    required this.createdAt,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        if (solicitudId != null) 'solicitud_id': solicitudId,
        'created_at': createdAt.toIso8601String(),
        'payload': payload,
      };

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'] as String,
      kind: QueueItemKind.values.firstWhere(
        (e) => e.name == json['kind'],
        orElse: () => QueueItemKind.evaluationSave,
      ),
      solicitudId: json['solicitud_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      payload: (json['payload'] as Map? ?? {}).cast<String, dynamic>(),
    );
  }

  EvaluacionCampoForm? get evaluacionForm {
    if (kind != QueueItemKind.evaluationSave) return null;
    final map = (payload['evaluacion'] is Map
            ? payload['evaluacion'] as Map
            : payload)
        .cast<String, dynamic>();
    return EvaluacionCampoForm(
      ingresoMensual: map['ingreso_mensual']?.toString() ?? '0.00',
      egresoMensual: map['egreso_mensual']?.toString() ?? '0.00',
      cuotaDeudasMensual: map['cuota_deudas_mensual']?.toString() ?? '0.00',
      actividadEconomica: map['actividad_economica']?.toString() ?? '',
      fuenteIngresos: map['fuente_ingresos']?.toString() ?? '',
      antiguedadLaboralMeses:
          int.tryParse(map['antiguedad_laboral_meses']?.toString() ?? '') ?? 0,
      calificacionAsfi: map['calificacion_asfi']?.toString() ?? 'A',
      coordenadas: map['coordenadas']?.toString(),
      observaciones: map['observaciones']?.toString(),
    );
  }

  PrecalificacionForm? get precalificacionForm =>
      kind == QueueItemKind.prequalification
          ? PrecalificacionForm(
              socioId: payload['socio_id'] as int,
              productoId: payload['producto_id'] as int,
              monto: payload['monto']?.toString() ?? '0.00',
              plazoMeses: payload['plazo_meses'] as int,
              ingresoMensual: payload['ingreso_mensual']?.toString() ?? '0.00',
              egresoMensual: payload['egreso_mensual']?.toString() ?? '0.00',
              cuotaDeudasMensual:
                  payload['cuota_deudas_mensual']?.toString() ?? '0.00',
              antiguedadLaboralMeses:
                  payload['antiguedad_laboral_meses'] as int,
              calificacionAsfi: payload['calificacion_asfi']?.toString(),
              fuenteIngresos: payload['fuente_ingresos']?.toString(),
            )
          : null;

  String? get clientId => payload['client_id']?.toString();
  String? get photoFilePath => payload['photo_file_path']?.toString();
  String? get filename => payload['filename']?.toString();
  String? get fotoId => payload['foto_id']?.toString();
}

class SyncConflict {
  final String id;
  final QueueItem item;
  final String error;
  final int statusCode;
  final DateTime timestamp;

  const SyncConflict({
    required this.id,
    required this.item,
    required this.error,
    required this.statusCode,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'item': item.toJson(),
        'error': error,
        'status_code': statusCode,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    return SyncConflict(
      id: json['id'] as String,
      item: QueueItem.fromJson((json['item'] as Map).cast<String, dynamic>()),
      error: json['error'] as String,
      statusCode: json['status_code'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class CachedData<T> {
  final T data;
  final DateTime timestamp;

  const CachedData({
    required this.data,
    required this.timestamp,
  });
}

class SyncResult {
  final int syncedCount;
  final int pendingCount;
  final int conflictsCount;
  final bool isUnauthorized;
  final bool isNetworkError;
  final String? message;

  const SyncResult({
    this.syncedCount = 0,
    this.pendingCount = 0,
    this.conflictsCount = 0,
    this.isUnauthorized = false,
    this.isNetworkError = false,
    this.message,
  });

  bool get isSuccess => !isUnauthorized && !isNetworkError;
}
