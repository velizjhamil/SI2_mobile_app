import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _twoFactorEnabled = true;
  bool _biometricsEnabled = true;
  bool _copied = false;

  void _copyId() {
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ID FST-INST-884920-BO copiado al portapapeles'),
        duration: Duration(seconds: 1),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Tarjeta Principal de Perfil (Dra. Elena Rossi)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    // Avatar con foto
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.forestGreen.withOpacity(0.5), width: 2),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=256&q=80',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 36, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Dra. Elena Rossi',
                                style: GoogleFonts.manrope(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.forestGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.forestGreen.withOpacity(0.3)),
                            ),
                            child: Text(
                              'Oficial & Gestor Autorizado',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Forest Microfinanzas & Banca Digital S.A.',
                            style: TextStyle(fontSize: 11, color: subtextColor),
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: _copyId,
                            child: Row(
                              children: [
                                Text(
                                  'ID: FST-INST-884920-BO',
                                  style: TextStyle(fontSize: 10, color: subtextColor, fontFamily: 'monospace'),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _copied ? '✓ Copiado' : 'Copiar',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Personalización de Interfaz (SELECTOR BLANCO / NEGRO - MODO CLARO / OSCURO)
              Text(
                'PERSONALIZACIÓN DE INTERFAZ',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: subtextColor,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
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
                          child: Icon(
                            isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                            color: accentColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tema Visual de la Aplicación',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                            ),
                            Text(
                              isDark ? 'Modo Oscuro (Dark Forest)' : 'Modo Claro (Light Clean)',
                              style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Selector Segmentado de Botones Claro / Oscuro
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF272B29) : const Color(0xFFE8EDE9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          // Botón Claro (Blanco)
                          GestureDetector(
                            onTap: () => themeProvider.setDarkMode(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: !isDark ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: !isDark ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.wb_sunny, size: 13, color: !isDark ? AppColors.forestGreen : subtextColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Claro',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: !isDark ? AppColors.forestGreen : subtextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Botón Oscuro (Negro)
                          GestureDetector(
                            onTap: () => themeProvider.setDarkMode(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.forestGreen : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isDark ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.nightlight_round, size: 13, color: isDark ? Colors.white : subtextColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Oscuro',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : subtextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Seguridad y Autenticación
              Text(
                'SEGURIDAD Y AUTENTICACIÓN',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: subtextColor,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    // Switch 2FA
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.forestGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.verified_user_outlined, color: accentColor, size: 18),
                      ),
                      title: Text('Doble Factor de Autenticación (2FA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      subtitle: Text('Verificación mediante Token OTP y SMS Seguro', style: TextStyle(fontSize: 11, color: subtextColor)),
                      trailing: Switch(
                        value: _twoFactorEnabled,
                        activeColor: AppColors.forestGreen,
                        onChanged: (val) => setState(() => _twoFactorEnabled = val),
                      ),
                    ),
                    Divider(height: 1, color: borderColor),

                    // Switch Biometría
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.forestGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.fingerprint, color: accentColor, size: 18),
                      ),
                      title: Text('Biometría FaceID / Huella Digital', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      subtitle: Text('Autenticación biométrica para firma de operaciones', style: TextStyle(fontSize: 11, color: subtextColor)),
                      trailing: Switch(
                        value: _biometricsEnabled,
                        activeColor: AppColors.forestGreen,
                        onChanged: (val) => setState(() => _biometricsEnabled = val),
                      ),
                    ),
                    Divider(height: 1, color: borderColor),

                    // Sincronización Offline
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.forestGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.storage_outlined, color: accentColor, size: 18),
                      ),
                      title: Text('Sincronización Local / Almacenamiento Offline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      subtitle: Text('Gestor de base de datos cifrada SQLite en terminal', style: TextStyle(fontSize: 11, color: subtextColor)),
                      trailing: Icon(Icons.chevron_right, size: 18, color: subtextColor),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Cumplimiento y Supervisión Financiera
              Text(
                'CUMPLIMIENTO Y SUPERVISIÓN FINANCIERA',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: subtextColor,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.description_outlined, color: subtextColor, size: 18),
                      ),
                      title: Text('Contrato de Servicios Financieros y Custodia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      subtitle: Text('Regulado por Autoridad de Supervisión del Sistema Financiero', style: TextStyle(fontSize: 11, color: subtextColor)),
                      trailing: Icon(Icons.chevron_right, size: 18, color: subtextColor),
                      onTap: () {},
                    ),
                    Divider(height: 1, color: borderColor),
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.business_outlined, color: subtextColor, size: 18),
                      ),
                      title: Text('Entidad Financiera Emisora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      subtitle: Text('Forest Financial Trust & Banking Services', style: TextStyle(fontSize: 11, color: subtextColor)),
                      trailing: Icon(Icons.chevron_right, size: 18, color: subtextColor),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botón Cerrar Sesión Segura
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                  label: const Text(
                    'CERRAR SESIÓN SEGURA',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent, letterSpacing: 0.8),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.08),
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
