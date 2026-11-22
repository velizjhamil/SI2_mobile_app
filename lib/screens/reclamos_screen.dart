import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/reclamo_model.dart';
import '../models/socio_model.dart';
import '../services/socio_service.dart';

class ReclamosScreen extends StatefulWidget {
  final SocioService? service;

  const ReclamosScreen({super.key, this.service});

  @override
  State<ReclamosScreen> createState() => _ReclamosScreenState();
}

class _ReclamosScreenState extends State<ReclamosScreen> {
  late final SocioService _service = widget.service ?? SocioService();
  late Future<SocioResult<List<ReclamoItem>>> _future;
  List<SocioCredit> _credits = [];

  static const List<Map<String, String>> _tiposReclamo = [
    {'id': 'CREDITO', 'label': 'Crédito'},
    {'id': 'AHORRO', 'label': 'Cuentas de Ahorro'},
    {'id': 'CAJA', 'label': 'Caja y Ventanilla'},
    {'id': 'COBRO_INDEBIDO', 'label': 'Cobro Indebido'},
    {'id': 'ATENCION', 'label': 'Atención al Cliente'},
    {'id': 'OTRO', 'label': 'Otro'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _loadCredits();
  }

  void _load() {
    setState(() {
      _future = _service.claims();
    });
  }

  Future<void> _loadCredits() async {
    final res = await _service.credits();
    if (res.success && mounted) {
      setState(() {
        _credits = res.value ?? [];
      });
    }
  }

  Color _estadoColor(String estado) {
    switch (estado.toUpperCase()) {
      case 'REGISTRADO':
        return Colors.blue;
      case 'EN_ATENCION':
        return AppColors.warning;
      case 'RESPONDIDO':
        return const Color(0xFF7B1FA2);
      case 'CERRADO':
        return AppColors.forestGreen;
      case 'ESCALADO_ASFI':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  Future<void> _nuevoReclamoModal() async {
    String selectedTipo = 'CREDITO';
    int? selectedCreditoId = _credits.isNotEmpty ? _credits.first.id : null;
    final descripcionCtrl = TextEditingController();
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
                'Registrar Reclamo',
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
                        'Punto de Reclamo (Ley 393 de Servicios Financieros). Plazo legal de respuesta: 5 días hábiles.',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: const Key('nuevo_reclamo_tipo_field'),
                        initialValue: selectedTipo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Reclamo *',
                          border: OutlineInputBorder(),
                        ),
                        items: _tiposReclamo
                            .map((t) => DropdownMenuItem(
                                  value: t['id'],
                                  child: Text(t['label']!),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedTipo = val);
                          }
                        },
                      ),
                      if (selectedTipo == 'CREDITO' && _credits.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          key: const Key('nuevo_reclamo_credito_field'),
                          initialValue: selectedCreditoId,
                          decoration: const InputDecoration(
                            labelText: 'Crédito Relacionado (opcional)',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Ninguno'),
                            ),
                            ..._credits.map((c) => DropdownMenuItem<int?>(
                                  value: c.id,
                                  child: Text(
                                    c.number.isNotEmpty
                                        ? '${c.number} (${c.product})'
                                        : c.product,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (val) {
                            setDialogState(() => selectedCreditoId = val);
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('nuevo_reclamo_descripcion_field'),
                        controller: descripcionCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Descripción del reclamo *',
                          hintText: 'Detalle los hechos y su solicitud...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'La descripción es obligatoria';
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
                  key: const Key('nuevo_reclamo_submit_btn'),
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

                          final res = await _service.createClaim(
                            tipo: selectedTipo,
                            descripcion: descripcionCtrl.text.trim(),
                            creditoId: selectedTipo == 'CREDITO'
                                ? selectedCreditoId
                                : null,
                          );

                          if (!ctx.mounted) return;

                          if (res.success) {
                            Navigator.pop(dialogCtx);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Reclamo ${res.value?.numeroReclamo ?? ''} registrado exitosamente.',
                                ),
                                backgroundColor: AppColors.forestGreen,
                              ),
                            );
                            _load();
                          } else {
                            setDialogState(() {
                              enviando = false;
                              errorLocal = res.error ??
                                  'Error al registrar el reclamo.';
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
                      : const Text('Registrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _darConformidad(ReclamoItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aceptar Conformidad'),
        content: Text(
          '¿Está conforme con la respuesta otorgada al reclamo ${item.numeroReclamo}? El reclamo pasará a estado CERRADO.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('confirmar_conformidad_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await _service.registerConformity(item.id, conforme: true);
    if (!mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conformidad registrada. Reclamo cerrado.'),
          backgroundColor: AppColors.forestGreen,
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Error al registrar conformidad.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _escalarAsfi(ReclamoItem item, {required bool porPlazoVencido}) async {
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
                porPlazoVencido
                    ? 'Escalar a ASFI (Plazo Vencido)'
                    : 'Disconformidad / Escalar a ASFI',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.error,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      porPlazoVencido
                          ? 'El plazo legal de respuesta (5 días hábiles) ha vencido sin respuesta. Su reclamo será remitido a la Defensoría del Consumidor Financiero de la ASFI.'
                          : 'Indique el motivo por el cual no está conforme con la respuesta. Su reclamo será remitido a la ASFI para segunda instancia.',
                      style: GoogleFonts.dmSans(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('reclamo_motivo_field'),
                      controller: motivoCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Motivo de disconformidad *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Debe indicar el motivo';
                        }
                        return null;
                      },
                    ),
                    if (errorLocal != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorLocal!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: enviando ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  key: const Key('confirmar_escalamiento_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
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

                          final res = await _service.registerConformity(
                            item.id,
                            conforme: false,
                            motivo: motivoCtrl.text.trim(),
                          );

                          if (!ctx.mounted) return;

                          if (res.success) {
                            Navigator.pop(dialogCtx);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Reclamo escalado a la ASFI exitosamente.',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            _load();
                          } else {
                            setDialogState(() {
                              enviando = false;
                              errorLocal =
                                  res.error ?? 'Error al escalar a ASFI.';
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
                      : const Text('Escalar a ASFI'),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LEY 393 · PUNTO DE RECLAMO',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: accentColor,
              ),
            ),
            Text(
              'Atención al Consumidor',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('nuevo_reclamo_btn'),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nuevo Reclamo'),
        onPressed: _nuevoReclamoModal,
      ),
      body: FutureBuilder<SocioResult<List<ReclamoItem>>>(
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
                      result?.error ?? 'Error al cargar los reclamos',
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

          final claims = result.value ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Banner informativo Ley 393
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E2838)
                      : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1565C0).withValues(alpha: 0.3)
                        : const Color(0xFF90CAF9),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: Color(0xFF1976D2), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Los reclamos registrados en el Punto de Reclamo deben ser respondidos en un plazo máximo de 5 días hábiles. En caso de disconformidad o vencimiento, puede solicitar su escalamiento a la ASFI.',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFFBBDEFB)
                              : const Color(0xFF0D47A1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'MIS RECLAMOS REGISTRADOS',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: subtextColor,
                ),
              ),
              const SizedBox(height: 8),
              if (claims.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined,
                            size: 48, color: subtextColor),
                        const SizedBox(height: 12),
                        Text(
                          'No tienes reclamos registrados.',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Si tienes alguna inconformidad con tus servicios o productos, puedes presionar "Nuevo Reclamo".',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...claims.map((item) {
                  final colorEstado = _estadoColor(item.estado);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: item.vencido
                            ? AppColors.error.withValues(alpha: 0.5)
                            : borderColor,
                        width: item.vencido ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Número y Estado
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.numeroReclamo,
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
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            Text(
                              'Tipo: ${item.tipoLabel}',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                            if (item.fechaRegistro.isNotEmpty)
                              Text(
                                '· Reg: ${item.fechaRegistro.split('T').first}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                            if (item.fechaLimiteRespuesta.isNotEmpty)
                              Text(
                                '· Límite: ${item.fechaLimiteRespuesta.split('T').first}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: item.vencido
                                      ? AppColors.error
                                      : subtextColor,
                                  fontWeight: item.vencido
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                        if (item.vencido) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_off_outlined,
                                    size: 14, color: AppColors.error),
                                const SizedBox(width: 4),
                                Text(
                                  'Plazo legal vencido (> 5 días hábiles sin respuesta)',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          item.descripcion,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),

                        // Sección de Respuesta
                        if (item.respuesta != null &&
                            item.respuesta!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceHigh
                                  : AppColors.softGreen,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Respuesta de la Entidad',
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                      ),
                                    ),
                                    if (item.procedente != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: item.procedente == true
                                              ? AppColors.forestGreen
                                                  .withValues(alpha: 0.15)
                                              : AppColors.error
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.procedente == true
                                              ? 'PROCEDENTE'
                                              : 'NO PROCEDENTE',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: item.procedente == true
                                              ? AppColors.forestGreen
                                              : AppColors.error,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.respuesta!,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: textColor,
                                  ),
                                ),
                                if (item.fechaRespuesta != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Respondido: ${item.fechaRespuesta!.split('T').first}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      color: subtextColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // Acciones según estado
                        if (item.isRespondido) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  key: Key('reclamo_conforme_btn_${item.id}'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.forestGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  icon: const Icon(Icons.thumb_up_alt_outlined,
                                      size: 16),
                                  label: const Text('Conforme'),
                                  onPressed: () => _darConformidad(item),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: Key('reclamo_escalar_btn_${item.id}'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side:
                                        const BorderSide(color: AppColors.error),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  icon: const Icon(Icons.gavel, size: 16),
                                  label: const Text('Escalar a ASFI'),
                                  onPressed: () => _escalarAsfi(item,
                                      porPlazoVencido: false),
                                ),
                              ),
                            ],
                          ),
                        ] else if (item.vencido &&
                            (item.isRegistrado || item.isEnAtencion)) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: Key(
                                  'reclamo_escalar_vencido_btn_${item.id}'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.gavel, size: 16),
                              label: const Text(
                                'Escalar a ASFI por vencimiento de plazo',
                              ),
                              onPressed: () =>
                                  _escalarAsfi(item, porPlazoVencido: true),
                            ),
                          ),
                        ],

                        if (item.isEscaladoAsfi) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.gavel,
                                        size: 14, color: AppColors.error),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Escalado a la ASFI (Defensoría del Consumidor)',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.motivoDisconformidad != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Motivo: ${item.motivoDisconformidad}',
                                    style: GoogleFonts.dmSans(fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        if (item.isCerrado) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.forestGreen.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 14, color: AppColors.forestGreen),
                                const SizedBox(width: 4),
                                Text(
                                  'Reclamo cerrado con conformidad del socio.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.forestGreen,
                                  ),
                                ),
                              ],
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
