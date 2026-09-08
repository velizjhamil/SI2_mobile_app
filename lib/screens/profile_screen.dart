import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';


class SocioProfileScreen extends StatefulWidget {
  const SocioProfileScreen({super.key});

  @override
  State<SocioProfileScreen> createState() => _SocioProfileScreenState();
}

class _SocioProfileScreenState extends State<SocioProfileScreen> {
  bool _twoFactorEnabled = true;
  bool _biometricsEnabled = true;
  bool _notificationsEnabled = true;
  bool _copied = false;

  // Datos del Socio (idealmente obtenidos desde un AuthProvider / UserState)
  final String _nombreSocio = 'Juan Carlos Pérez';
  final String _tipoSocio = 'Socio Platinum - Ahorrista';
  final String _codigoSocio = 'SOC-884920-BO';

  void _copySocioId() {
    Clipboard.setData(ClipboardData(text: _codigoSocio));
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código de socio $_codigoSocio copiado'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
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
              // 1. Tarjeta Principal del Socio
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    // Avatar con iniciales del Socio (sin foto de perfil)
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withOpacity(0.15),
                        border: Border.all(color: accentColor.withOpacity(0.5), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _nombreSocio.split(' ').map((e) => e[0]).take(2).join(),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: accentColor),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nombreSocio,
                            style: GoogleFonts.manrope(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: accentColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              _tipoSocio,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _copySocioId,
                            child: Row(
                              children: [
                                Text(
                                  'Código: $_codigoSocio',
                                  style: TextStyle(fontSize: 11, color: subtextColor, fontFamily: 'monospace'),
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

              // 2. Sección: Preferencias de Interfaz
              _buildSectionHeader('PREFERENCIAS DE INTERFAZ', subtextColor),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
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
                      child: Icon(
                        isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                        color: accentColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tema de la Aplicación',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isDark ? 'Modo Oscuro' : 'Modo Claro',
                            style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildThemeSegmentedPicker(themeProvider, isDark, subtextColor),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Sección: Seguridad de la Cuenta del Socio
              _buildSectionHeader('SEGURIDAD DE LA CUENTA', subtextColor),
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
                      leading: _buildIconContainer(icon: Icons.lock_outline, accentColor: accentColor),
                      title: Text('Cambiar PIN / Contraseña', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      subtitle: Text('Actualiza tu clave de acceso a la banca', style: TextStyle(fontSize: 11, color: subtextColor)),
                      trailing: Icon(Icons.chevron_right, size: 18, color: subtextColor),
                      onTap: () {},
                    ),
                    Divider(height: 1, color: borderColor),
                    SwitchListTile(
                      secondary: _buildIconContainer(icon: Icons.fingerprint, accentColor: accentColor),
                      title: Text('Ingreso Biométrico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      subtitle: Text('Usa Huella o FaceID para iniciar sesión', style: TextStyle(fontSize: 11, color: subtextColor)),
                      value: _biometricsEnabled,
                      activeColor: AppColors.forestGreen,
                      onChanged: (val) => setState(() => _biometricsEnabled = val),
                    ),
                    Divider(height: 1, color: borderColor),
                    SwitchListTile(
                      secondary: _buildIconContainer(icon: Icons.shield_outlined, accentColor: accentColor),
                      title: Text('Autenticación en Dos Pasos (2FA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      subtitle: Text('Confirmación de operaciones vía SMS/OTP', style: TextStyle(fontSize: 11, color: subtextColor)),
                      value: _twoFactorEnabled,
                      activeColor: AppColors.forestGreen,
                      onChanged: (val) => setState(() => _twoFactorEnabled = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Sección: Ajustes Generales del Socio
              _buildSectionHeader('MI INFORMACIÓN Y ALERTAS', subtextColor),
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
                      leading: _buildIconContainer(icon: Icons.badge_outlined, accentColor: accentColor),
                      title: Text('Datos Personales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      subtitle: Text('Dirección, teléfono y correo electrónico', style: TextStyle(fontSize: 11, color: subtextColor)),
                      trailing: Icon(Icons.chevron_right, size: 18, color: subtextColor),
                      onTap: () {},
                    ),
                    Divider(height: 1, color: borderColor),
                    SwitchListTile(
                      secondary: _buildIconContainer(icon: Icons.notifications_none_outlined, accentColor: accentColor),
                      title: Text('Notificaciones de Movimientos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      subtitle: Text('Alertas sobre transferencias y pagos', style: TextStyle(fontSize: 11, color: subtextColor)),
                      value: _notificationsEnabled,
                      activeColor: AppColors.forestGreen,
                      onChanged: (val) => setState(() => _notificationsEnabled = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botón Cerrar Sesión
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                  label: const Text(
                    'CERRAR SESIÓN',
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

  // --- Métodos Auxiliares de UI ---

  Widget _buildSectionHeader(String title, Color subtextColor) {
    return Text(
      title,
      style: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        color: subtextColor,
      ),
    );
  }

  Widget _buildIconContainer({required IconData icon, required Color accentColor}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.forestGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: accentColor, size: 18),
    );
  }

  Widget _buildThemeSegmentedPicker(ThemeProvider themeProvider, bool isDark, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF272B29) : const Color(0xFFE8EDE9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
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
    );
  }
}