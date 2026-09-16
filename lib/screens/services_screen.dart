import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import 'transferencia_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Servicios & Microfinanzas',
          style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi, color: accentColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Online',
                  style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildCategoryHeader(context, 'BANCA DIGITAL & CUENTAS', 'Operaciones transaccionales cotidianas'),
          const SizedBox(height: 8),
          _buildServiceTile(context, Icons.account_balance_wallet, 'Consulta de Saldos y Extractos', 'Detalle de cuentas y exportación PDF', 'Operativo'),
          _buildServiceTile(context, Icons.swap_horiz, 'Transferencias entre Cuentas', 'Entre tus propias cuentas', 'Instantáneo',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TransferenciaScreen(),
                ),
              );
            }),
          _buildServiceTile(context, Icons.credit_card, 'Pago Móvil de Cuotas', 'Amortización y recibos digitales', 'Débito Auto'),
          const SizedBox(height: 18),

          _buildCategoryHeader(context, 'CRÉDITOS & INVERSIONES DPF', 'Simuladores y financiamiento digital'),
          const SizedBox(height: 8),
          _buildServiceTile(context, Icons.calendar_month, 'Cronograma de Pagos y DPF', 'Amortización francesa y DPF 6.75%', '6.75% TEA'),
          _buildServiceTile(context, Icons.description, 'Solicitud Digital de Crédito', 'Preaprobación 100% digital', 'Preaprobado'),
          const SizedBox(height: 18),

          _buildCategoryHeader(context, 'OPERACIONES EN TERRENO', 'Herramientas del Oficial de Campo'),
          const SizedBox(height: 8),
          _buildServiceTile(context, Icons.assignment, 'Levantamiento Socioeconómico', 'Flujo de caja, ventas y costos', 'Flujo Caja'),
          _buildServiceTile(context, Icons.camera_alt, 'Captura de Fotos y GPS', 'Marca de agua y satelital', 'GPS ±3.5m'),
          _buildServiceTile(context, Icons.bolt, 'Precalificación y Scoring', 'Motor de riesgo en tiempo real', 'Score 300-850'),
          _buildServiceTile(context, Icons.cloud_sync, 'Sincronización Offline', 'Almacenamiento SQLite local', 'Sincronizado'),
          const SizedBox(height: 18),

          _buildCategoryHeader(context, 'SEGURIDAD & NOTIFICACIONES', 'Biometría FIDO2 y control de sesión'),
          const SizedBox(height: 8),
          _buildServiceTile(context, Icons.fingerprint, 'Autenticación Biométrica', 'FaceID, TouchID y PIN seguro', 'FIDO2'),
          _buildServiceTile(context, Icons.notifications_active, 'Notificaciones Push', 'Alertas de cuotas y vencimientos', 'Alertas'),
          _buildServiceTile(context, Icons.logout, 'Cierre Seguro de Sesión', 'Revocación de tokens y limpieza', 'Seguridad'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String title, String subtitle) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;
    final subtextColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.dmSans(fontSize: 11, color: subtextColor),
        ),
      ],
    );
  }

  Widget _buildServiceTile(BuildContext context, IconData icon, String title, String subtitle, String badge, {VoidCallback? onTap}) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.forestGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: accentColor),
              ),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: subtextColor),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.chevron_right, size: 16, color: subtextColor),
        onTap: onTap ?? () {},
      ),
    );
  }
}
