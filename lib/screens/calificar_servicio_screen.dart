import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/feedback_model.dart';
import '../services/feedback_service.dart';

class CalificarServicioScreen extends StatefulWidget {
  final FeedbackService? service;

  const CalificarServicioScreen({super.key, this.service});

  @override
  State<CalificarServicioScreen> createState() => _CalificarServicioScreenState();
}

class _CalificarServicioScreenState extends State<CalificarServicioScreen> {
  late final FeedbackService _service;

  final _formKey = GlobalKey<FormState>();
  String _selectedServicio = 'CREDITO';
  int _calificacion = 5;
  int? _recomendaria;
  final TextEditingController _comentarioController = TextEditingController();

  bool _submitting = false;
  bool _loadingHistory = true;
  String? _historyError;
  List<EncuestaFeedback> _ratings = [];

  static const List<Map<String, String>> _servicios = [
    {'id': 'CREDITO', 'label': 'Crédito'},
    {'id': 'AHORRO', 'label': 'Ahorro'},
    {'id': 'CAJA', 'label': 'Caja y Ventanilla'},
    {'id': 'ATENCION', 'label': 'Atención al Cliente'},
    {'id': 'APP_MOVIL', 'label': 'Banca Móvil'},
    {'id': 'OTRO', 'label': 'Otro'},
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FeedbackService();
    _loadRatings();
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _loadRatings() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    final res = await _service.misCalificaciones();
    if (!mounted) return;

    setState(() {
      _loadingHistory = false;
      if (res.success) {
        _ratings = res.value ?? [];
      } else {
        _historyError = res.error;
      }
    });
  }

  Future<void> _submitFeedback() async {
    if (_submitting) return;

    setState(() => _submitting = true);

    final res = await _service.calificar(
      servicio: _selectedServicio,
      calificacion: _calificacion,
      recomendaria: _recomendaria,
      comentario: _comentarioController.text,
      canal: 'MOVIL',
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Gracias por tu opinión! Tu calificación ha sido registrada.'),
          backgroundColor: AppColors.forestGreen,
        ),
      );
      _comentarioController.clear();
      setState(() {
        _recomendaria = null;
        _calificacion = 5;
      });
      _loadRatings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Error al enviar calificación.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Muy insatisfecho';
      case 2:
        return 'Insatisfecho';
      case 3:
        return 'Neutral / Regular';
      case 4:
        return 'Satisfecho';
      case 5:
        return 'Excelente / Muy satisfecho';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Calificar servicio',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadRatings,
        color: AppColors.forestGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Formulario de Calificación
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu experiencia nos importa',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Evalúa nuestro servicio para ayudarnos a mejorar cada día.',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: subtextColor,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Selector de Servicio
                      Text(
                        'SERVICIO A EVALUAR',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedServicio,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: accentColor, width: 1.5),
                          ),
                          fillColor: isDark
                              ? AppColors.darkSurfaceHigh
                              : AppColors.lightSurfaceHigh,
                          filled: true,
                        ),
                        dropdownColor: cardBg,
                        items: _servicios.map((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'],
                            child: Text(
                              s['label'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedServicio = val);
                        },
                      ),
                      const SizedBox(height: 18),

                      // 2. Selector de 1-5 Estrellas
                      Text(
                        'CALIFICACIÓN GENERAL',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                final starNum = index + 1;
                                final filled = starNum <= _calificacion;
                                return IconButton(
                                  onPressed: () =>
                                      setState(() => _calificacion = starNum),
                                  icon: Icon(
                                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                                    size: 38,
                                    color: filled ? Colors.amber : subtextColor.withValues(alpha: 0.4),
                                  ),
                                  splashRadius: 24,
                                );
                              }),
                            ),
                            Text(
                              _getRatingText(_calificacion),
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 3. Recomendación NPS 0-10 (opcional)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '¿NOS RECOMENDARÍAS? (0-10)',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (_recomendaria != null)
                            GestureDetector(
                              onTap: () => setState(() => _recomendaria = null),
                              child: Text(
                                'Limpiar',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: subtextColor,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '0 = Nada probable, 10 = Muy probable',
                        style: GoogleFonts.dmSans(fontSize: 11, color: subtextColor),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(11, (index) {
                            final isSelected = _recomendaria == index;
                            Color chipColor = accentColor;
                            if (index <= 6) {
                              chipColor = Colors.redAccent;
                            } else if (index <= 8) {
                              chipColor = Colors.amber;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _recomendaria = isSelected ? null : index;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? chipColor
                                        : (isDark
                                            ? AppColors.darkSurfaceHigh
                                            : AppColors.lightSurfaceHigh),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? chipColor : borderColor,
                                    ),
                                  ),
                                  child: Text(
                                    '$index',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : textColor,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 4. Comentario opcional
                      Text(
                        'COMENTARIOS ADICIONALES (OPCIONAL)',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _comentarioController,
                        maxLines: 3,
                        maxLength: 1000,
                        style: TextStyle(fontSize: 13, color: textColor),
                        decoration: InputDecoration(
                          hintText:
                              'Escribe aquí cualquier sugerencia o detalle sobre tu experiencia...',
                          hintStyle: TextStyle(fontSize: 12, color: subtextColor),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: accentColor, width: 1.5),
                          ),
                          fillColor: isDark
                              ? AppColors.darkSurfaceHigh
                              : AppColors.lightSurfaceHigh,
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Botón Enviar
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submitFeedback,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _submitting ? 'ENVIANDO...' : 'ENVIAR CALIFICACIÓN',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.forestGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Sección: Historial de Calificaciones
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MIS CALIFICACIONES ANTERIORES',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (!_loadingHistory)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      color: subtextColor,
                      onPressed: _loadRatings,
                      tooltip: 'Actualizar',
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_loadingHistory)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_historyError != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _historyError!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_ratings.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.rate_review_outlined,
                          size: 40, color: subtextColor.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text(
                        'Aún no has calificado ningún servicio.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tus opiniones anteriores se mostrarán en esta sección.',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _ratings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _ratings[index];
                    final dateStr = item.fecha != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(item.fecha!)
                        : '';

                    return Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.servicioLabel,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              Row(
                                children: List.generate(5, (starIdx) {
                                  return Icon(
                                    starIdx < item.calificacion
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 16,
                                    color: starIdx < item.calificacion
                                        ? Colors.amber
                                        : subtextColor.withValues(alpha: 0.4),
                                  );
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (item.recomendaria != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Text(
                                    'Recomendación: ',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      color: subtextColor,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: item.recomendaria! >= 9
                                          ? Colors.green.withValues(alpha: 0.15)
                                          : item.recomendaria! >= 7
                                              ? Colors.amber.withValues(alpha: 0.15)
                                              : Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${item.recomendaria}/10',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: item.recomendaria! >= 9
                                            ? Colors.green
                                            : item.recomendaria! >= 7
                                                ? Colors.amber.shade800
                                                : Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (item.comentario != null &&
                              item.comentario!.isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceHigh
                                    : AppColors.lightSurfaceHigh,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '"${item.comentario}"',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: textColor,
                                ),
                              ),
                            ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateStr,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: subtextColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurfaceHigh
                                      : AppColors.lightSurfaceHigh,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.canal,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: subtextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
