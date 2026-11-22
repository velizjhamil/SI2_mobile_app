import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/reprogramacion_model.dart';
import '../models/socio_model.dart';
import '../services/socio_service.dart';

class ReprogramacionScreen extends StatefulWidget {
  final int creditId;
  final SocioCredit? credit;
  final SocioService? service;

  const ReprogramacionScreen({
    super.key,
    required this.creditId,
    this.credit,
    this.service,
  });

  @override
  State<ReprogramacionScreen> createState() => _ReprogramacionScreenState();
}

class _ReprogramacionScreenState extends State<ReprogramacionScreen> {
  late final SocioService _service = widget.service ?? SocioService();
  late Future<SocioResult<List<ReprogramacionCreditoItem>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _service.creditReschedulingHistory(widget.creditId);
    });
  }

  Color _statusColor(String estado) {
    switch (estado.toUpperCase()) {
      case 'APROBADA':
        return AppColors.forestGreen;
      case 'SOLICITADA':
        return AppColors.warning;
      case 'RECHAZADA':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  Future<void> _mostrarDialogoSolicitud() async {
    final plazoCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool enviando = false;
    String? errorLocal;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                'Solicitar Reprogramación',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modifica el plazo de amortización de tu crédito según normativa ASFI.',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('reprogramacion_plazo_field'),
                        controller: plazoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nuevo plazo (meses) *',
                          hintText: 'Ej. 24',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Ingrese el nuevo plazo';
                          }
                          final numVal = int.tryParse(val.trim());
                          if (numVal == null || numVal <= 0) {
                            return 'El plazo debe ser mayor a 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('reprogramacion_motivo_field'),
                        controller: motivoCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Motivo de la reprogramación *',
                          hintText:
                              'Describa la razón del cambio de condiciones...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'El motivo es obligatorio';
                          }
                          return null;
                        },
                      ),
                      if (errorLocal != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            errorLocal!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: enviando ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  key: const Key('reprogramacion_submit_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: enviando
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            enviando = true;
                            errorLocal = null;
                          });

                          final res = await _service.requestRescheduling(
                            widget.creditId,
                            nuevoPlazoMeses: int.parse(plazoCtrl.text.trim()),
                            motivo: motivoCtrl.text.trim(),
                          );

                          if (!ctx.mounted) return;

                          if (res.success) {
                            Navigator.pop(dialogCtx);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Solicitud de reprogramación enviada correctamente.',
                                ),
                                backgroundColor: AppColors.forestGreen,
                              ),
                            );
                            _load();
                          } else {
                            setDialogState(() {
                              enviando = false;
                              errorLocal = res.error ??
                                  'No se pudo enviar la solicitud.';
                            });
                          }
                        },
                  child: enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enviar Solicitud'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Reprogramación de Crédito',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Actualizar historial',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('solicitar_reprogramacion_btn'),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('Nueva Solicitud'),
        onPressed: _mostrarDialogoSolicitud,
      ),
      body: FutureBuilder<SocioResult<List<ReprogramacionCreditoItem>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data;
          if (result == null || !result.success) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result?.error ?? 'Error al cargar reprogramaciones',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = result.value ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header del crédito
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history_edu, color: accentColor, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Detalles del Crédito',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.credit != null) ...[
                      Text(
                        'Número: ${widget.credit!.number.isNotEmpty ? widget.credit!.number : widget.credit!.product}',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saldo pendiente: ${widget.credit!.currency} ${widget.credit!.outstandingBalance}',
                        style: GoogleFonts.dmSans(color: subtextColor),
                      ),
                      Text(
                        'Estado: ${widget.credit!.status}',
                        style: GoogleFonts.dmSans(color: subtextColor),
                      ),
                    ] else
                      Text(
                        'Crédito ID: ${widget.creditId}',
                        style: GoogleFonts.dmSans(color: textColor),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'HISTORIAL DE SOLICITUDES',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: subtextColor,
                ),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text(
                      'No tienes solicitudes de reprogramación registradas para este crédito.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(color: subtextColor),
                    ),
                  ),
                )
              else
                ...items.map((item) {
                  final colorEstado = _statusColor(item.estado);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Solicitud #${item.id}',
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorEstado.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.estado,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colorEstado,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nuevo plazo solicitado: ${item.nuevoPlazoMeses} meses',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Motivo: ${item.motivo}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: subtextColor,
                          ),
                        ),
                        if (item.fechaSolicitud.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Fecha solicitud: ${item.fechaSolicitud.split('T').first}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: subtextColor,
                            ),
                          ),
                        ],
                        if (item.isAprobada) ...[
                          const Divider(height: 16),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.forestGreen.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.saldoCapital.isNotEmpty)
                                  Text(
                                    'Saldo reprogramado: Bs. ${item.saldoCapital}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (item.interesDiferido != null)
                                  Text(
                                    'Interés diferido (1° cuota): Bs. ${item.interesDiferido}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (item.moraCondonada != null)
                                  Text(
                                    'Mora condonada: Bs. ${item.moraCondonada}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (item.cuotasReprogramadas != null)
                                  Text(
                                    'Cuotas reprogramadas: ${item.cuotasReprogramadas}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (item.isRechazada &&
                            item.motivoRechazo != null &&
                            item.motivoRechazo!.isNotEmpty) ...[
                          const Divider(height: 16),
                          Text(
                            'Motivo de rechazo: ${item.motivoRechazo}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }
}
