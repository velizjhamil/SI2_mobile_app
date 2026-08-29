import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

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
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PATRIMONIO CONSOLIDADO',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: accentColor,
              ),
            ),
            Text(
              'Estructura de Portafolio',
              style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta de Patrimonio y Desglose
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
                    'PATRIMONIO TOTAL BAJO GESTIÓN',
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
                      Text(
                        '\$142,500.00',
                        style: GoogleFonts.manrope(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'USD',
                        style: GoogleFonts.dmSans(fontSize: 13, color: subtextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Métricas de Rendimiento
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GANANCIAS NO REALIZADAS',
                                style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.bold, color: subtextColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '+\$18,420.00 (+14.8%)',
                                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: accentColor),
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
                            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DIVIDENDOS YTD',
                                style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.bold, color: subtextColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '+\$4,180.50',
                                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: accentColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Barra Segmentada de Distribución
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('DISTRIBUCIÓN DE CARTERA', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: subtextColor)),
                      Text('100% Asignado', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor)),
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
                        Flexible(flex: 48, child: Container(decoration: BoxDecoration(color: accentColor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(5))))),
                        Flexible(flex: 32, child: Container(color: AppColors.forestGreen)),
                        Flexible(flex: 20, child: Container(decoration: const BoxDecoration(color: Color(0xFF526059), borderRadius: BorderRadius.horizontal(right: Radius.circular(5))))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Leyendas
                  Row(
                    children: [
                      _buildLegendDot(accentColor, 'Acciones 48.0%', subtextColor),
                      const SizedBox(width: 12),
                      _buildLegendDot(AppColors.forestGreen, 'Bonos 31.5%', subtextColor),
                      const SizedBox(width: 12),
                      _buildLegendDot(const Color(0xFF526059), 'Inmuebles 20.5%', subtextColor),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Posiciones en Cartera
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Posiciones en Cartera',
                  style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  '3 Activos',
                  style: GoogleFonts.dmSans(fontSize: 11, color: subtextColor),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildPortfolioAssetCard(
              context: context,
              icon: Icons.show_chart,
              name: 'Acciones Tech',
              symbol: 'GLOBAL-TECH',
              shares: r'48 u. • Prom: $1,427.08',
              value: r'$68,500.00',
              change: '+5.8%',
              sharePct: '48.0% del portafolio',
            ),
            const SizedBox(height: 8),

            _buildPortfolioAssetCard(
              context: context,
              icon: Icons.account_balance,
              name: 'Bonos del Tesoro',
              symbol: 'UST-10Y',
              shares: r'32 u. • Prom: $1,406.25',
              value: r'$45,000.00',
              change: '+1.2%',
              sharePct: '31.5% del portafolio',
            ),
            const SizedBox(height: 8),

            _buildPortfolioAssetCard(
              context: context,
              icon: Icons.business,
              name: 'Fondo Inmobiliario',
              symbol: 'REIT-LATAM',
              shares: r'20 u. • Prom: $1,450.00',
              value: r'$29,000.00',
              change: '-0.5%',
              sharePct: '20.5% del portafolio',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label, Color subtextColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: subtextColor)),
      ],
    );
  }

  Widget _buildPortfolioAssetCard({
    required BuildContext context,
    required IconData icon,
    required String name,
    required String symbol,
    required String shares,
    required String value,
    required String change,
    required String sharePct,
  }) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;
    final isPos = change.startsWith('+');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.forestGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(symbol, style: TextStyle(fontSize: 9, color: accentColor, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text(shares, style: TextStyle(fontSize: 11, color: subtextColor)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)),
              Text(
                '$sharePct ($change)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isPos ? accentColor : Colors.pinkAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
