String _string(dynamic value) => value?.toString() ?? '';
int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;

class ReprogramacionCreditoItem {
  final int id;
  final int creditoId;
  final String? numeroCredito;
  final String estado;
  final String canal;
  final String motivo;
  final int nuevoPlazoMeses;
  final String saldoCapital;
  final String? interesDiferido;
  final String? interesCorrido;
  final String? seguroDiferido;
  final String? moraCondonada;
  final int? plazoAnterior;
  final int? cuotasReprogramadas;
  final String? motivoRechazo;
  final String fechaSolicitud;
  final String? fechaResolucion;

  const ReprogramacionCreditoItem({
    required this.id,
    required this.creditoId,
    this.numeroCredito,
    required this.estado,
    required this.canal,
    required this.motivo,
    required this.nuevoPlazoMeses,
    required this.saldoCapital,
    this.interesDiferido,
    this.interesCorrido,
    this.seguroDiferido,
    this.moraCondonada,
    this.plazoAnterior,
    this.cuotasReprogramadas,
    this.motivoRechazo,
    required this.fechaSolicitud,
    this.fechaResolucion,
  });

  bool get isSolicitada => estado == 'SOLICITADA';
  bool get isAprobada => estado == 'APROBADA';
  bool get isRechazada => estado == 'RECHAZADA';

  factory ReprogramacionCreditoItem.fromJson(Map<String, dynamic> json) =>
      ReprogramacionCreditoItem(
        id: _int(json['id']),
        creditoId: _int(json['credito_id']),
        numeroCredito: json['numero_credito']?.toString(),
        estado: _string(json['estado']),
        canal: _string(json['canal']),
        motivo: _string(json['motivo']),
        nuevoPlazoMeses: _int(json['nuevo_plazo_meses']),
        saldoCapital: _string(json['saldo_capital']),
        interesDiferido: json['interes_diferido']?.toString(),
        interesCorrido: json['interes_corrido']?.toString(),
        seguroDiferido: json['seguro_diferido']?.toString(),
        moraCondonada: json['mora_condonada']?.toString(),
        plazoAnterior: json['plazo_anterior'] != null
            ? _int(json['plazo_anterior'])
            : null,
        cuotasReprogramadas: json['cuotas_reprogramadas'] != null
            ? _int(json['cuotas_reprogramadas'])
            : null,
        motivoRechazo: json['motivo_rechazo']?.toString(),
        fechaSolicitud: _string(json['fecha_solicitud']),
        fechaResolucion: json['fecha_resolucion']?.toString(),
      );
}
