import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/extracto_credito_model.dart';
import '../models/socio_model.dart';
import '../services/socio_service.dart';

/// Pantalla de Extracto de Pagos y Amortización por Crédito (S3, S4).
class ExtractoCreditoScreen extends StatefulWidget {
  final int creditId;
  final SocioCredit? credit;
  final SocioService? service;

  const ExtractoCreditoScreen({
    super.key,
    required this.creditId,
    this.credit,
    this.service,
  });

  @override
  State<ExtractoCreditoScreen> createState() => _ExtractoCreditoScreenState();
}

class _ExtractoCreditoScreenState extends State<ExtractoCreditoScreen> {
  late final SocioService _service = widget.service ?? SocioService();
  late Future<SocioResult<ExtractoCredito>> _future;

  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final desdeStr = _desde != null
        ? '${_desde!.year.toString().padLeft(4, '0')}-${_desde!.month.toString().padLeft(2, '0')}-${_desde!.day.toString().padLeft(2, '0')}'
        : null;
    final hastaStr = _hasta != null
        ? '${_hasta!.year.toString().padLeft(4, '0')}-${_hasta!.month.toString().padLeft(2, '0')}-${_hasta!.day.toString().padLeft(2, '0')}'
        : null;

    setState(() {
      _future = _service.extractoCredito(
        widget.creditId,
        desde: desdeStr,
        hasta: hastaStr,
      );
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _desde = null;
      _hasta = null;
    });
    _load();
  }

  Future<void> _seleccionarFecha(BuildContext context, bool esDesde) async {
    final actual = esDesde ? _desde : _hasta;
    final inicial = actual ?? DateTime.now();
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: esDesde ? 'Seleccionar fecha desde' : 'Seleccionar fecha hasta',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (seleccionada != null) {
      setState(() {
        if (esDesde) {
          _desde = seleccionada;
        } else {
          _hasta = seleccionada;
        }
      });
      _load();
    }
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
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXTRACTO DE CRÉDITO',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: accentColor,
              ),
            ),
            Text(
              widget.credit?.number.isNotEmpty == true
                  ? 'Extracto ${widget.credit!.number}'
                  : 'Extracto de Pagos',
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
            icon: Icon(Icons.refresh, color: accentColor),
            onPressed: _load,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: FutureBuilder<SocioResult<ExtractoCredito>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data;
          if (result == null || !result.success || result.value == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(
                      result?.error ?? 'No se pudo cargar el extracto del crédito.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(fontSize: 14, color: textColor),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _load,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forestGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final extracto = result.value!;
          final info = extracto.credito;
          final moneda = info.moneda.isNotEmpty ? info.moneda : 'Bs.';

          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Encabezado del Crédito
                _buildCreditHeader(info, moneda, cardBg, borderColor, textColor, subtextColor, accentColor, isDark),
                const SizedBox(height: 16),

                // 2. Barra de Filtro de Fechas
                _buildDateFilterBar(cardBg, borderColor, textColor, subtextColor, accentColor),
                const SizedBox(height: 16),

                // 3. Resumen de Cuotas y Seguro
                _buildSummarySection(extracto.resumen, moneda, cardBg, borderColor, textColor, subtextColor, accentColor, isDark),
                const SizedBox(height: 20),

                // 4. Tabla / Lista de Pagos Realizados
                _buildPaymentsSection(extracto.pagos, extracto.totales, moneda, cardBg, borderColor, textColor, subtextColor, accentColor, isDark),
                const SizedBox(height: 20),

                // 5. Tabla del Plan de Amortización
                _buildScheduleSection(extracto.cuotas, moneda, cardBg, borderColor, textColor, subtextColor, accentColor, isDark),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreditHeader(
    ExtractoCreditoInfo info,
    String moneda,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    Color accentColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.account_balance, color: accentColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.producto,
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      info.numeroCredito,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: subtextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: info.estado.toUpperCase() == 'VIGENTE'
                      ? (isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9))
                      : (isDark ? const Color(0xFF352B1E) : const Color(0xFFFFF3E0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  info.estado,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: info.estado.toUpperCase() == 'VIGENTE'
                        ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                        : (isDark ? const Color(0xFFFFB74D) : const Color(0xFFEF6C00)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chipBadge('Tipo: ${info.tipoCreditoLabel}', accentColor.withValues(alpha: 0.12), accentColor),
              _chipBadge('Sistema: ${info.tipoAmortizacionLabel}', isDark ? AppColors.darkSurfaceHigh : Colors.grey.shade100, textColor),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _headerMetric(
                  'MONTO DESEMBOLSADO',
                  '$moneda ${info.montoDesembolsado}',
                  textColor,
                  subtextColor,
                ),
              ),
              Expanded(
                child: _headerMetric(
                  'SALDO PENDIENTE',
                  '$moneda ${info.saldoPendiente}',
                  textColor,
                  subtextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _headerMetric(
                  'TASA INTERÉS ANUAL',
                  '${info.tasaInteresAnual ?? "—"}%',
                  textColor,
                  subtextColor,
                ),
              ),
              Expanded(
                child: _headerMetric(
                  'TASA SEGURO DESGRAVAMEN',
                  '${info.tasaSeguroDesgravamen ?? "0.00"}%',
                  textColor,
                  subtextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _headerMetric(String label, String value, Color textColor, Color subtextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: subtextColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilterBar(
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    Color accentColor,
  ) {
    final tieneFiltro = _desde != null || _hasta != null;
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
              Row(
                children: [
                  Icon(Icons.filter_list, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    'Filtrar pagos por fecha',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              if (tieneFiltro)
                TextButton(
                  onPressed: _limpiarFiltros,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Limpiar',
                    style: GoogleFonts.dmSans(fontSize: 11, color: Colors.redAccent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _seleccionarFecha(context, true),
                  icon: Icon(Icons.calendar_today, size: 14, color: accentColor),
                  label: Text(
                    _desde != null
                        ? '${_desde!.day}/${_desde!.month}/${_desde!.year}'
                        : 'Desde',
                    style: GoogleFonts.dmSans(fontSize: 12, color: textColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _seleccionarFecha(context, false),
                  icon: Icon(Icons.calendar_today, size: 14, color: accentColor),
                  label: Text(
                    _hasta != null
                        ? '${_hasta!.day}/${_hasta!.month}/${_hasta!.year}'
                        : 'Hasta',
                    style: GoogleFonts.dmSans(fontSize: 12, color: textColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    ExtractoResumen resumen,
    String moneda,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    Color accentColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESUMEN DE CUOTAS Y SEGURO',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _summaryBox(
                  'Pagadas',
                  '${resumen.cuotasPagadas}',
                  isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9),
                  const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryBox(
                  'Vencidas',
                  '${resumen.cuotasVencidas}',
                  isDark ? const Color(0xFF381E1E) : const Color(0xFFFFEBEE),
                  const Color(0xFFC62828),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryBox(
                  'Pendientes',
                  '${resumen.cuotasPendientes}',
                  isDark ? const Color(0xFF1B2A38) : const Color(0xFFE3F2FD),
                  const Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceHigh : AppColors.softGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Seguro programado total:',
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                ),
                Text(
                  '$moneda ${resumen.seguroProgramado}',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsSection(
    List<ExtractoPagoItem> pagos,
    ExtractoTotales totales,
    String moneda,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    Color accentColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HISTORIAL DE PAGOS',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: subtextColor,
                ),
              ),
              Text(
                '${pagos.length} ${pagos.length == 1 ? "pago" : "pagos"}',
                style: GoogleFonts.dmSans(fontSize: 11, color: accentColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (pagos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No se registraron pagos en el rango seleccionado.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontSize: 13, color: subtextColor),
                ),
              ),
            )
          else ...[
            for (var p in pagos) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceHigh : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cuota #${p.numeroCuota} • ${p.numeroRecibo}',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '$moneda ${p.total}',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.fecha ?? "—"}${p.modalidad != null ? " • ${p.modalidad}" : ""}',
                      style: GoogleFonts.dmSans(fontSize: 11, color: subtextColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Capital: $moneda ${p.capital} | Interés: $moneda ${p.interes} | Seguro: $moneda ${p.seguro}${p.mora != "0.00" && p.mora.isNotEmpty ? " | Mora: $moneda ${p.mora}" : ""}',
                      style: GoogleFonts.dmSans(fontSize: 10.5, color: subtextColor),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Totales Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL PAGADO (${totales.pagos} recibos)',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      Text(
                        '$moneda ${totales.total}',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Capital: $moneda ${totales.capital} • Interés: $moneda ${totales.interes} • Seguro: $moneda ${totales.seguro} • Mora: $moneda ${totales.mora}',
                    style: GoogleFonts.dmSans(fontSize: 10.5, color: subtextColor),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleSection(
    List<ExtractoCuotaItem> cuotas,
    String moneda,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
    Color accentColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PLAN DE AMORTIZACIÓN',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: subtextColor,
                ),
              ),
              Text(
                '${cuotas.length} cuotas',
                style: GoogleFonts.dmSans(fontSize: 11, color: accentColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (cuotas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No se encontró el plan de amortización.',
                  style: GoogleFonts.dmSans(fontSize: 13, color: subtextColor),
                ),
              ),
            )
          else ...[
            for (var c in cuotas) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceHigh : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cuota #${c.numero} • Vence: ${c.fechaVencimiento}',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        _estadoCuotaBadge(c.estado, isDark),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cuota total: $moneda ${c.montoTotal}',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                        Text(
                          'Saldo: $moneda ${c.saldoCapital}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cap: $moneda ${c.capital} | Int: $moneda ${c.interes} | Seg: $moneda ${c.seguro}',
                      style: GoogleFonts.dmSans(fontSize: 10.5, color: subtextColor),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _estadoCuotaBadge(String estado, bool isDark) {
    Color bg;
    Color fg;
    final upper = estado.toUpperCase();
    if (upper == 'PAGADA' || upper == 'PAGADO') {
      bg = isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9);
      fg = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    } else if (upper == 'VENCIDA' || upper == 'VENCIDO') {
      bg = isDark ? const Color(0xFF381E1E) : const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
    } else {
      bg = isDark ? const Color(0xFF1B2A38) : const Color(0xFFE3F2FD);
      fg = const Color(0xFF1565C0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        estado,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
