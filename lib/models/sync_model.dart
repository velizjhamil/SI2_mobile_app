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
  final int attemptCount;
  final String? lastError;

  const QueueItem({
    required this.id,
    required this.kind,
    this.solicitudId,
    required this.createdAt,
    required this.payload,
    this.attemptCount = 0,
    this.lastError,
  });

  QueueItem copyWith({
    String? id,
    QueueItemKind? kind,
    int? solicitudId,
    DateTime? createdAt,
    Map<String, dynamic>? payload,
    int? attemptCount,
    String? lastError,
  }) =>
      QueueItem(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        solicitudId: solicitudId ?? this.solicitudId,
        createdAt: createdAt ?? this.createdAt,
        payload: payload ?? this.payload,
        attemptCount: attemptCount ?? this.attemptCount,
        lastError: lastError ?? this.lastError,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        if (solicitudId != null) 'solicitud_id': solicitudId,
        'created_at': createdAt.toIso8601String(),
        'payload': payload,
        'attempt_count': attemptCount,
        if (lastError != null) 'last_error': lastError,
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
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
      lastError: json['last_error'] as String?,
    );
  }

  EvaluacionCampoForm? get evaluacionForm {
    if (kind != QueueItemKind.evaluationSave) return null;
    final map = (payload['evaluacion'] is Map
            ? payload['evaluacion'] as Map
            : payload)
        .cast<String, dynamic>();

    final ingreso = map['ingreso_mensual']?.toString();
    final egreso = map['egreso_mensual']?.toString();
    final cuota = map['cuota_deudas_mensual']?.toString();
    final actividad = map['actividad_economica']?.toString();
    final fuente = map['fuente_ingresos']?.toString();
    final antiguedadRaw = map['antiguedad_laboral_meses'];
    final calificacion = map['calificacion_asfi']?.toString();

    if (ingreso == null ||
        ingreso.trim().isEmpty ||
        egreso == null ||
        egreso.trim().isEmpty ||
        cuota == null ||
        cuota.trim().isEmpty ||
        actividad == null ||
        actividad.trim().isEmpty ||
        fuente == null ||
        fuente.trim().isEmpty ||
        antiguedadRaw == null ||
        calificacion == null ||
        calificacion.trim().isEmpty) {
      return null;
    }

    final antiguedad = int.tryParse(antiguedadRaw.toString());
    if (antiguedad == null || antiguedad < 0) {
      return null;
    }

    return EvaluacionCampoForm(
      ingresoMensual: ingreso.trim(),
      egresoMensual: egreso.trim(),
      cuotaDeudasMensual: cuota.trim(),
      actividadEconomica: actividad.trim(),
      fuenteIngresos: fuente.trim(),
      antiguedadLaboralMeses: antiguedad,
      calificacionAsfi: calificacion.trim(),
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
