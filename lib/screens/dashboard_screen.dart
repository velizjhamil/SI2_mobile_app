import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/cuenta_ahorro_model.dart';
import '../services/cuentas_service.dart';
import '../widgets/asset_card.dart';
import 'transferencia_screen.dart';

/// Consulta de Saldos y Extractos con datos reales del backend.
///
/// Mantiene el estilo visual existente (AppColors, GoogleFonts); solo cambia
/// el origen de datos: [CuentasService.listarMisCuentas] en vez de valores
/// hardcodeados. [cuentasService] se puede inyectar en tests con un fake.
class DashboardScreen extends StatefulWidget {
  final CuentasService? cuentasService;

  const DashboardScreen({super.key, this.cuentasService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceHighest
                  : AppColors.lightSurfaceHigh,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.forestGreen.withOpacity(0.4), width: 1.5),
            ),
            child: Icon(Icons.person, color: accentColor, size: 20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FOREST BANK',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: accentColor,
              ),
            ),
            Text(
              'Inversiones & Banca',
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
            onPressed: _recargar,
            icon: Icon(Icons.refresh, color: subtextColor, size: 20),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.notifications_none, color: accentColor, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Sección Valor del Portafolio (saldo real)
            Text(
              'SALDO TOTAL DISPONIBLE',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: subtextColor,
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilder<CuentasResult>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _CuentasLoading();
                }
                if (snapshot.hasError) {
                  return _CuentasError(
                    mensaje:
                        'No se pudieron cargar los saldos. Intente nuevamente.',
                    onRetry: _recargar,
                  );
                }
                final result = snapshot.data;
                if (result == null || !result.success) {
                  return _CuentasError(
                    mensaje: result?.error ??
                        'No se pudieron cargar los saldos. Intente nuevamente.',
                    onRetry: _recargar,
                  );
                }
                if (result.cuentas.isEmpty) {
                  return _CuentasEmpty(onRetry: _recargar);
                }
                return _CuentasBody(
                  cuentas: result.cuentas,
                  onRetry: _recargar,
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Cuerpo con datos reales: total, bloqueado, distribución y cuentas.
class _CuentasBody extends StatelessWidget {
  final List<CuentaAhorro> cuentas;
  final VoidCallback onRetry;

  const _CuentasBody({required this.cuentas, required this.onRetry});

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
    // mostraría un saldo disponible falso -- se desglosa por moneda.
    final monedas = cuentas.map((c) => c.currency.currencyCode).toSet();
    final textoDisponible = monedas.length <= 1
        ? '${cuentas.first.currency.symbol} ${totalDisponible.toStringAsFixed(2)}'
        : _desglosePorMoneda(cuentas, (c) => c.availableBalance);
    final textoBloqueado = monedas.length <= 1
        ? '${cuentas.first.currency.symbol} ${totalBloqueado.toStringAsFixed(2)}'
        : _desglosePorMoneda(cuentas, (c) => c.blockedBalance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                textoDisponible,
                style: GoogleFonts.dmSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.forestGreen.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet,
                      color: accentColor, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    '${cuentas.length} ${cuentas.length == 1 ? 'cuenta' : 'cuentas'}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          'Saldos de tus cuentas de ahorro',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: subtextColor,
          ),
        ),
        const SizedBox(height: 14),

        // Botones Principales Depositar / Invertir
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'DEPOSITAR',
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.forestGreen),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'INVERTIR',
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        letterSpacing: 0.8),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // 2. Sección Acciones Rápidas (Grid 3 columnas)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACCIONES RÁPIDAS',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: subtextColor,
              ),
            ),
            Text(
              'Ver catálogo >',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.15,
          children: [
            _buildQuickActionTile(
                context, Icons.account_balance_wallet, 'Cuentas', 'Saldos & Ext.'),
            _buildQuickActionTile(
              context,
              Icons.swap_horiz,
              'Envíos',
              'Transferencias',
              onTap: () async {
                final exito = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const TransferenciaScreen(),
                  ),
                );
                if (exito == true) onRetry();
              },
            ),
            _buildQuickActionTile(
                context, Icons.credit_card, 'Créditos', 'Pago Cuotas'),
            _buildQuickActionTile(
                context, Icons.calendar_month, 'Inversión', 'Cronograma DPF'),
            _buildQuickActionTile(
                context, Icons.description, 'Préstamos', 'Solicitud Créd.'),
            _buildQuickActionTile(
                context, Icons.assignment_ind, 'Terreno', 'Oficial Campo'),
          ],
        ),
        const SizedBox(height: 22),

        // 3. Distribución por cuenta + Saldo bloqueado
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Distribución por cuenta',
                    style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                  Icon(Icons.more_horiz, color: subtextColor),
                ],
              ),
              Text(
                'Participación según saldo disponible',
                style: GoogleFonts.dmSans(fontSize: 11, color: subtextColor),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < cuentas.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _buildAllocationBar(
                  '${cuentas[i].productType} • ${cuentas[i].accountNumber}',
                  totalDisponible > 0
                      ? (cuentas[i].availableBalance /
                              totalDisponible *
                              100)
                      : 0,
                  i == 0
                      ? accentColor
                      : (i == 1
                          ? AppColors.forestGreen
                          : const Color(0xFF526059)),
                  textColor,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Card Soft Green: Saldo bloqueado total (real)
        Container(
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SALDO BLOQUEADO TOTAL',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                textoBloqueado,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.graphite,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor:
                      (totalDisponible + totalBloqueado) > 0
                          ? (totalBloqueado /
                                  (totalDisponible + totalBloqueado))
                              .clamp(0.0, 1.0)
                          : 0.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.forestGreen,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 4. Tus cuentas de ahorro (datos reales)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tus cuentas de ahorro',
              style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor),
            ),
            Text(
              '${cuentas.length} ${cuentas.length == 1 ? 'cuenta activa' : 'cuentas activas'}',
              style: GoogleFonts.dmSans(fontSize: 11, color: subtextColor),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < cuentas.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          AssetCard(
            title: '${cuentas[i].productType} • ${cuentas[i].accountNumber}',
            subtitle: '${cuentas[i].status} • ${cuentas[i].currency.name}',
            percentageChange:
                '+${cuentas[i].availableBalance.toStringAsFixed(2)}',
            amount: cuentas[i].formattedAvailable,
            portfolioShare:
                'Bloqueado: ${cuentas[i].formattedBlocked} • ${cuentas[i].registrationDate}',
            icon: Icons.account_balance,
            isHighlighted: i == 0,
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActionTile(
    BuildContext context, IconData icon, String subtitle, String title,
    {VoidCallback? onTap}) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    final tile = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style:
                    TextStyle(fontSize: 8, color: subtextColor, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                title,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: tile,
    );
  }

  Widget _buildAllocationBar(
      String title, double pct, Color barColor, Color textColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor),
                  overflow: TextOverflow.ellipsis),
            ),
            Text('${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: barColor)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (pct / 100.0).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Suma [monto] agrupado por moneda y lo formatea como "Bs 100.00 + $ 50.00"
/// para socios con cuentas en más de una moneda (nunca mezcla montos de
/// monedas distintas bajo un solo símbolo).
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

class _CuentasLoading extends StatelessWidget {
  const _CuentasLoading();

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text('Cargando saldos...',
              style: GoogleFonts.dmSans(fontSize: 13, color: subtextColor)),
        ],
      ),
    );
  }
}

class _CuentasError extends StatelessWidget {
  final String mensaje;
  final VoidCallback onRetry;

  const _CuentasError({required this.mensaje, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 32),
          const SizedBox(height: 8),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, color: textColor),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _CuentasEmpty extends StatelessWidget {
  final VoidCallback onRetry;

  const _CuentasEmpty({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 40, color: subtextColor),
          const SizedBox(height: 8),
          Text(
            'No tienes cuentas de ahorro registradas.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Si crees que es un error, recarga tus saldos.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 12, color: subtextColor),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Recargar'),
          ),
        ],
      ),
    );
  }
}
