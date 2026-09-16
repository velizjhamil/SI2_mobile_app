import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/theme_provider.dart';
import '../services/mock_auth_service.dart';
import 'main_navigation_screen.dart';

// Paleta Minimalista CoopIA (Extraída exactamente de tu imagen)
abstract class CoopPalette {
  static const Color c1 = Color(0xFF051F20); // Verde Noche Profundo (Muy Oscuro)
  static const Color c2 = Color(0xFF0B2B26); // Verde Bosque Oscuro
  static const Color c3 = Color(0xFF163832); // Verde Álamo Profundo
  static const Color c4 = Color(0xFF235347); // Verde Eucalipto
  static const Color c5 = Color(0xFF8EB69B); // Verde Sage Suave
  static const Color c6 = Color(0xFFDAF1DE); // Verde Menta Desaturado (Muy Claro)
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'usuario@cooperativa.com');
  final _passwordController = TextEditingController(text: 'CoopIA#2026');
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isBioLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans(color: Colors.white)),
        backgroundColor: CoopPalette.c4,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _goToMain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final result = await _authService.login(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _goToMain();
    } else {
      _showError(result.error ?? 'Error de autenticación.');
    }
  }

  Future<void> _handleBiometricLogin() async {
    setState(() => _isBioLoading = true);
    final available = await _authService.isBiometricAvailable();
    if (!mounted) return;

    if (!available) {
      setState(() => _isBioLoading = false);
      _showError('Biometría no disponible.');
      return;
    }

    final result = await _authService.authenticateWithBiometrics();
    if (!mounted) return;
    setState(() => _isBioLoading = false);

    if (result.success) {
      _goToMain();
    } else {
      _showError(result.error ?? 'Autenticación fallida.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;

    // Asignación de colores para diseño minimalista
    final bgColor = isDark ? CoopPalette.c1 : CoopPalette.c6;
    final surfaceColor = isDark ? CoopPalette.c2 : Colors.white;
    final textColor = isDark ? Colors.white : CoopPalette.c1;
    final subtitleColor = isDark ? CoopPalette.c5 : CoopPalette.c4;
    final borderColor = isDark ? CoopPalette.c3 : CoopPalette.c5.withOpacity(0.3);
    final inputBg = isDark ? CoopPalette.c1 : CoopPalette.c6.withOpacity(0.4);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Container(
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono sobrio y minimalista
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? CoopPalette.c3 : CoopPalette.c6,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: isDark ? CoopPalette.c5 : CoopPalette.c2,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Título y Subtítulo
                  Text(
                    'CoopIA',
                    style: GoogleFonts.manrope(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestión para Cooperativas',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: subtitleColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Formulario
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Campo Correo
                        Text(
                          'CORREO ELECTRÓNICO',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('emailField'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.dmSans(color: textColor, fontSize: 13),
                          validator: (v) => (v == null || !v.contains('@')) ? 'Correo no válido' : null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: CoopPalette.c5, width: 1.2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.redAccent),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.redAccent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Campo Contraseña
                        Text(
                          'CONTRASEÑA',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('passwordField'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: GoogleFonts.dmSans(color: textColor, fontSize: 13),
                          validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: subtitleColor,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: CoopPalette.c5, width: 1.2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.redAccent),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.redAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Botón Iniciar Sesión (Sólido y Mate)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? CoopPalette.c3 : CoopPalette.c2,
                        foregroundColor: CoopPalette.c6,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: CoopPalette.c6, strokeWidth: 2),
                            )
                          : Text(
                              'Iniciar Sesión',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Botón Biométrico (Outlined Discreto)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _isBioLoading ? null : _handleBiometricLogin,
                      icon: _isBioLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: CoopPalette.c5),
                            )
                          : Icon(Icons.fingerprint, color: subtitleColor, size: 18),
                      label: Text(
                        'Ingresar con Biometría',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}