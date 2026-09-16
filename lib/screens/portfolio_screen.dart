import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/cuenta_ahorro_model.dart';
import '../services/cuentas_service.dart';

/// Estructura de Portafolio con saldos reales del backend.
///
/// Mantiene el estilo visual existente (AppColors, GoogleFonts); solo cambia
/// el origen de datos a [CuentasService.listarMisCuentas].
class PortfolioScreen extends StatefulWidget {
  final CuentasService? cuentasService;

  const PortfolioScreen({super.key, this.cuentasService});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late final CuentasService _service;
  late Future<CuentasResult> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.cuentasService ?? CuentasService();
    _future = _service.listarMisCuentas();
  }

  void _recargar() {
    setState(() {
      _future = _service.listarMisCuentas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SALDOS Y EXTRACTOS',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: accentColor,
              ),
            ),
            Text(
              'Estructura de Portafolio',
              style: GoogleFonts.manrope(
                  fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _recargar,
            icon: Icon(Icons.refresh, color: accentColor),
          ),
        ],
      ),
      body: FutureBuilder<CuentasResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PortfolioLoading();
          }
          if (snapshot.hasError) {
            return _PortfolioError(
              mensaje:
                  'No se pudieron cargar los saldos. Intente nuevamente.',
              onRetry: _recargar,
            );
          }
          final result = snapshot.data;
          if (result == null || !result.success) {
            return _PortfolioError(
              mensaje: result?.error ??
                  'No se pudieron cargar los saldos. Intente nuevamente.',
              onRetry: _recargar,
            );
          }
          if (result.cuentas.isEmpty) {
            return _PortfolioEmpty(onRetry: _recargar);
          }
          return _PortfolioBody(cuentas: result.cuentas);
        },
      ),
    );
  }
}

class _PortfolioBody extends StatelessWidget {
  final List<CuentaAhorro> cuentas;

  const _PortfolioBody({required this.cuentas});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    final totalDisponible =
        cuentas.fold<double>(0, (sum, c) => sum + c.availableBalance);
    final totalBloqueado =
        cuentas.fold<double>(0, (sum, c) => sum + c.blockedBalance);
    // Con una sola moneda el símbolo de la primera cuenta es exacto. Con
    // varias, sumar montos de monedas distintas bajo un solo símbolo
    // mostraría un saldo disponible falso -- se desglosa por moneda (mismo
    // criterio que dashboard_screen.dart).
    final monedas = cuentas.map((c) => c.currency.currencyCode).toSet();
    final textoDisponible = monedas.length <= 1
        ? '${cuentas.first.currency.symbol} ${totalDisponible.toStringAsFixed(2)}'
        : _desglosePorMoneda(cuentas, (c) => c.availableBalance);
    final textoBloqueado = monedas.length <= 1
        ? '${cuentas.first.currency.symbol} ${totalBloqueado.toStringAsFixed(2)}'
        : _desglosePorMoneda(cuentas, (c) => c.blockedBalance);
    // El badge de código de moneda solo tiene sentido con una sola moneda;
    // con varias, ya va cada una en el desglose de arriba.
    final codigoIso = monedas.length <= 1 ? cuentas.first.currency.currencyCode : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta de Patrimonio y Desglose (real)
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
                Text(
                  'SALDO TOTAL DISPONIBLE',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        textoDisponible,
                        style: GoogleFonts.manrope(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      codigoIso,
                      style:
                          GoogleFonts.dmSans(fontSize: 13, color: subtextColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Métricas reales
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'N.º DE CUENTAS',
                              style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: subtextColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${cuentas.length}',
                              style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SALDO BLOQUEADO',
                              style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: subtextColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              textoBloqueado,
                              style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Barra Segmentada de Distribución (real)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DISTRIBUCIÓN DE CARTERA',
                        style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: subtextColor)),
                    Text('100% Asignado',
                        style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: accentColor)),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < cuentas.length; i++)
                        Flexible(
                          flex: _flexFor(cuentas[i], totalDisponible),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _segmentColor(i, accentColor),
                              borderRadius: _segmentRadius(
                                  i, cuentas.length),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Leyendas reales
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < cuentas.length; i++)
                      _buildLegendDot(
                        _segmentColor(i, accentColor),
                        '${cuentas[i].productType} ${_sharePct(cuentas[i], totalDisponible)}',
                        subtextColor,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Posiciones en Cartera (reales)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cuentas de ahorro',
                style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor),
              ),
              Text(
                '${cuentas.length} ${cuentas.length == 1 ? 'Cuenta' : 'Cuentas'}',
                style: GoogleFonts.dmSans(fontSize: 11, color: subtextColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < cuentas.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildCuentaCard(
              context: context,
              cuenta: cuentas[i],
              sharePct: _sharePct(cuentas[i], totalDisponible),
            ),
          ],
        ],
      ),
    );
  }

  int _flexFor(CuentaAhorro cuenta, double total) {
    if (total <= 0) return 1;
    final pct = (cuenta.availableBalance / total * 100).round();
    return pct <= 0 ? 1 : pct;
  }

  String _sharePct(CuentaAhorro cuenta, double total) {
    if (total <= 0) return '0.0%';
    return '${(cuenta.availableBalance / total * 100).toStringAsFixed(1)}%';
  }

  Color _segmentColor(int index, Color accent) {
    if (index == 0) return accent;
    if (index == 1) return AppColors.forestGreen;
    return const Color(0xFF526059);
  }

  BorderRadius _segmentRadius(int index, int total) {
    if (total == 1) return BorderRadius.circular(5);
    if (index == 0) {
      return const BorderRadius.horizontal(left: Radius.circular(5));
    }
    if (index == total - 1) {
      return const BorderRadius.horizontal(right: Radius.circular(5));
    }
    return BorderRadius.zero;
  }
}

Widget _buildLegendDot(Color color, String label, Color subtextColor) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: subtextColor)),
    ],
  );
}

Widget _buildCuentaCard({
  required BuildContext context,
  required CuentaAhorro cuenta,
  required String sharePct,
}) {
  final isDark = Provider.of<ThemeProvider>(context, listen: false).isDark;
  final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
  final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
  final textColor = isDark ? AppColors.darkText : AppColors.lightText;
  final subtextColor =
      isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
  final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.forestGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.account_balance, color: accentColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      cuenta.productType,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: textColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.forestGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(cuenta.currency.currencyCode,
                        style: TextStyle(
                            fontSize: 9,
                            color: accentColor,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Text(
                'N.º ${cuenta.accountNumber} • ${cuenta.status}',
                style: TextStyle(fontSize: 11, color: subtextColor),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(cuenta.formattedAvailable,
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: textColor)),
            Text(
              '$sharePct del total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Suma [monto] agrupado por moneda y lo formatea como "Bs 100.00 + $ 50.00"
/// para socios con cuentas en más de una moneda (nunca mezcla montos de
/// monedas distintas bajo un solo símbolo). Igual criterio que
/// dashboard_screen.dart.
String _desglosePorMoneda(
    List<CuentaAhorro> cuentas, double Function(CuentaAhorro) monto) {
  final porMoneda = <String, double>{};
  final simbolos = <String, String>{};
  for (final c in cuentas) {
    final codigo = c.currency.currencyCode;
    porMoneda[codigo] = (porMoneda[codigo] ?? 0) + monto(c);
    simbolos[codigo] = c.currency.symbol;
  }
  return porMoneda.entries
      .map((e) => '${simbolos[e.key]} ${e.value.toStringAsFixed(2)}')
      .join(' + ');
}

class _PortfolioLoading extends StatelessWidget {
  const _PortfolioLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('Cargando saldos...',
                style: GoogleFonts.dmSans(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _PortfolioError extends StatelessWidget {
  final String mensaje;
  final VoidCallback onRetry;

  const _PortfolioError({required this.mensaje, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 40),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioEmpty extends StatelessWidget {
  final VoidCallback onRetry;

  const _PortfolioEmpty({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 40),
            const SizedBox(height: 8),
            Text(
              'No tienes cuentas de ahorro registradas.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Si crees que es un error, recarga tus saldos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Recargar'),
            ),
          ],
        ),
      ),
    );
  }
}
