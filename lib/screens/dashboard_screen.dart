import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../widgets/asset_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceHighest : AppColors.lightSurfaceHigh,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.forestGreen.withOpacity(0.4), width: 1.5),
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
            onPressed: () {},
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
            // 1. Sección Valor del Portafolio
            Text(
              'VALOR TOTAL DEL PORTAFOLIO',
              style: GoogleFonts.dmSans(
                fontSize: 11,
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
                  r'$142,500.00',
                  style: GoogleFonts.dmSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.forestGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.forestGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up, color: accentColor, size: 13),
                      const SizedBox(width: 3),
                      Text(
                        '+2.4%',
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
              'Última actualización de saldos: Hoy 09:30 AM',
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'DEPOSITAR',
                        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'INVERTIR',
                        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor, letterSpacing: 0.8),
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
                _buildQuickActionTile(context, Icons.account_balance_wallet, 'Cuentas', 'Saldos & Ext.'),
                _buildQuickActionTile(context, Icons.swap_horiz, 'Envíos', 'Transferencias'),
                _buildQuickActionTile(context, Icons.credit_card, 'Créditos', 'Pago Cuotas'),
                _buildQuickActionTile(context, Icons.calendar_month, 'Inversión', 'Cronograma DPF'),
                _buildQuickActionTile(context, Icons.description, 'Préstamos', 'Solicitud Créd.'),
                _buildQuickActionTile(context, Icons.assignment_ind, 'Terreno', 'Oficial Campo'),
              ],
            ),
            const SizedBox(height: 22),

            // 3. Bento Grid: Asignación + Rendimiento Mensual
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
                        'Asignación de Activos',
                        style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      Icon(Icons.more_horiz, color: subtextColor),
                    ],
                  ),
                  Text(
                    'Distribución ponderada por clase de instrumento',
                    style: GoogleFonts.dmSans(fontSize: 11, color: subtextColor),
                  ),
                  const SizedBox(height: 14),

                  // Barras de Asignación
                  _buildAllocationBar('Acciones Tech', 48.0, accentColor, textColor),
                  const SizedBox(height: 8),
                  _buildAllocationBar('Bonos del Tesoro', 31.5, AppColors.forestGreen, textColor),
                  const SizedBox(height: 8),
                  _buildAllocationBar('Fondo Inmobiliario', 20.5, const Color(0xFF526059), textColor),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card Destacada Soft Green: Rendimiento Mensual
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
                    'RENDIMIENTO MENSUAL',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppColors.forestGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '+\$3,420.00 USD',
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
                      widthFactor: 0.75,
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

            // 4. Tus Activos e Instrumentos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tus Activos e Instrumentos',
                  style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  '3 posiciones activas',
                  style: GoogleFonts.dmSans(fontSize: 11, color: subtextColor),
                ),
              ],
            ),
            const SizedBox(height: 10),

            const AssetCard(
              title: 'Bonos del Tesoro',
              subtitle: 'Renta Fija Institucional',
              percentageChange: '+1.2%',
              amount: '\$45,000.00',
              portfolioShare: '31.5% del portafolio',
              icon: Icons.account_balance,
              isHighlighted: false,
            ),
            const SizedBox(height: 8),

            const AssetCard(
              title: 'Acciones Tech',
              subtitle: 'Renta Variable Global',
              percentageChange: '+5.8%',
              amount: '\$68,500.00',
              portfolioShare: '48.0% del portafolio',
              icon: Icons.show_chart,
              isHighlighted: true,
            ),
            const SizedBox(height: 8),

            const AssetCard(
              title: 'Fondo Inmobiliario',
              subtitle: 'Bienes Raíces & Infraestructura',
              percentageChange: '-0.5%',
              amount: '\$29,000.00',
              portfolioShare: '20.5% del portafolio',
              icon: Icons.business,
              isHighlighted: false,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(BuildContext context, IconData icon, String subtitle, String title) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Container(
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
                style: TextStyle(fontSize: 8, color: subtextColor, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationBar(String title, double pct, Color barColor, Color textColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
            Text('$pct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: barColor)),
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
            widthFactor: pct / 100.0,
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
