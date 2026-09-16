import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/cuenta_ahorro_model.dart';
import '../services/cuentas_service.dart';
import '../services/transferencias_service.dart';

/// Transferencia de saldo entre dos cuentas propias del socio.
///
/// Origen y destino salen de [CuentasService.listarMisCuentas]; el destino
/// excluye el origen y solo admite cuentas `ACTIVA` con la misma moneda
/// (defensa UX en profundidad: el backend valida igual). El envío exige
/// confirmación en un diálogo antes de llamar a
/// [TransferenciasService.transferir]. Al éxito cierra con
/// `Navigator.pop(context, true)` para que el llamador refresque saldos.
/// Los services se pueden inyectar en tests con fakes.
class TransferenciaScreen extends StatefulWidget {
  final CuentasService? cuentasService;
  final TransferenciasService? transferenciasService;

  const TransferenciaScreen({
    super.key,
    this.cuentasService,
    this.transferenciasService,
  });

  @override
  State<TransferenciaScreen> createState() => _TransferenciaScreenState();
}

class _TransferenciaScreenState extends State<TransferenciaScreen> {
  late final CuentasService _cuentasService;
  late final TransferenciasService _transferenciasService;
  late Future<CuentasResult> _future;

  final _montoController = TextEditingController();
  final _glosaController = TextEditingController();

  int? _origenId;
  int? _destinoId;
  bool _enviando = false;
  // Guarda contra doble-tap ANTES de que se abra el diálogo de confirmación
  // (o mientras está abierto). No dispara setState ni maneja ningún widget
  // animado -- a diferencia de [_enviando], que sí lo hace (spinner del
  // botón) y por eso solo se enciende después de confirmar.
  bool _procesando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cuentasService = widget.cuentasService ?? CuentasService();
    _transferenciasService =
        widget.transferenciasService ?? TransferenciasService();
    _future = _cuentasService.listarMisCuentas();
  }

  @override
  void dispose() {
    _montoController.dispose();
    _glosaController.dispose();
    super.dispose();
  }

  void _recargar() {
    setState(() {
      _future = _cuentasService.listarMisCuentas();
    });
  }

  static String _etiqueta(CuentaAhorro c) =>
      '${c.productType} • ${c.accountNumber}';

  CuentaAhorro? _porId(List<CuentaAhorro> cuentas, int? id) {
    if (id == null) return null;
    for (final c in cuentas) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Destinos válidos para el origen: excluye el origen, solo `ACTIVA`
  /// y misma moneda (`currencyCode`).
  List<CuentaAhorro> _destinosPara(List<CuentaAhorro> cuentas) {
    final origen = _porId(cuentas, _origenId);
    if (origen == null) return const [];
    return cuentas
        .where((c) =>
            c.id != origen.id &&
            c.status == 'ACTIVA' &&
            c.currency.currencyCode == origen.currency.currencyCode)
        .toList();
  }

  /// Valida el formulario. Retorna el mensaje en español o null si todo ok.
  /// El tope por saldo disponible es solo UX: el backend valida igual.
  String? _validar(List<CuentaAhorro> cuentas) {
    final origen = _porId(cuentas, _origenId);
    if (origen == null) return 'Seleccione la cuenta origen.';
    if (_porId(cuentas, _destinoId) == null) {
      return 'Seleccione la cuenta destino.';
    }
    final texto = _montoController.text.trim();
    if (texto.isEmpty) return 'Ingrese el monto.';
    final monto = double.tryParse(texto.replaceAll(',', '.'));
    if (monto == null || monto <= 0) {
      return 'El monto debe ser mayor a cero.';
    }
    if (monto > origen.availableBalance) {
      return 'El monto supera el saldo disponible.';
    }
    return null;
  }

  Future<void> _onTransferir(List<CuentaAhorro> cuentas) async {
    // Reentrancy: un doble-tap antes de que se abra el diálogo (o mientras
    // está abierto) no debe disparar dos POST de transferencia. `_procesando`
    // no dispara setState a propósito -- solo protege contra el reingreso,
    // sin animar ningún spinner mientras el diálogo modal está en pantalla.
    if (_procesando) return;
    _procesando = true;
    try {
      final problema = _validar(cuentas);
      if (problema != null) {
        setState(() => _error = problema);
        return;
      }
      final origen = _porId(cuentas, _origenId)!;
      final destino = _porId(cuentas, _destinoId)!;
      final monto =
          double.parse(_montoController.text.trim().replaceAll(',', '.'));

      final confirmado = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirmar transferencia'),
          content: Text(
            '¿Transferir ${destino.currency.symbol} ${monto.toStringAsFixed(2)} '
            'de ${_etiqueta(origen)} a ${_etiqueta(destino)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (!mounted || confirmado != true) return;

      setState(() {
        _enviando = true;
        _error = null;
      });
      final glosa = _glosaController.text.trim();
      final resultado = await _transferenciasService.transferir(
        cuentaOrigenId: origen.id,
        cuentaDestinoId: destino.id,
        monto: monto,
        glosa: glosa.isEmpty ? null : glosa,
      );
      if (!mounted) return;
      if (resultado.success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _enviando = false;
          _error = resultado.error ??
              'No se pudo completar la transferencia. Intente más tarde.';
        });
      }
    } finally {
      _procesando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Transferencia entre cuentas',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      body: FutureBuilder<CuentasResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _EstadoMensaje(
              mensaje:
                  'No se pudieron cargar sus cuentas. Intente nuevamente.',
              onRetry: _recargar,
            );
          }
          final result = snapshot.data;
          if (result == null || !result.success) {
            return _EstadoMensaje(
              mensaje: result?.error ??
                  'No se pudieron cargar sus cuentas. Intente nuevamente.',
              onRetry: _recargar,
            );
          }
          if (result.cuentas.isEmpty) {
            return const _EstadoMensaje(
              mensaje:
                  'No tiene cuentas registradas para transferir. '
                  'Necesita al menos dos cuentas propias.',
              onRetry: null,
            );
          }
          return _buildForm(context, result.cuentas, subtextColor);
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<CuentaAhorro> cuentas,
    Color subtextColor,
  ) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final destinos = _destinosPara(cuentas);
    final origen = _porId(cuentas, _origenId);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mueva saldo entre sus propias cuentas, sin salir de su patrimonio.',
              style: GoogleFonts.dmSans(fontSize: 12, color: subtextColor),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: const Key('dropdown-origen'),
              decoration: const InputDecoration(
                labelText: 'Cuenta origen',
                border: OutlineInputBorder(),
              ),
              initialValue: _origenId,
              items: [
                for (final c in cuentas)
                  DropdownMenuItem<int>(
                    value: c.id,
                    child: Text(
                      _etiqueta(c),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _enviando
                  ? null
                  : (id) {
                      setState(() {
                        _origenId = id;
                        // El destino anterior puede haber quedado inválido
                        // con el nuevo origen (otra moneda, o es el mismo
                        // origen elegido). `destinos` de este build todavía
                        // refleja el origen VIEJO -- si se lo usara acá para
                        // decidir, el destino elegido siempre figuraría en
                        // esa lista vieja y nunca se limpiaría. Se
                        // revalida contra `cuentas` + el nuevo origen.
                        final nuevoOrigen = _porId(cuentas, id);
                        final destinoSigueValido = _destinoId != null &&
                            nuevoOrigen != null &&
                            cuentas.any((c) =>
                                c.id == _destinoId &&
                                c.id != nuevoOrigen.id &&
                                c.status == 'ACTIVA' &&
                                c.currency.currencyCode ==
                                    nuevoOrigen.currency.currencyCode);
                        if (!destinoSigueValido) _destinoId = null;
                        _error = null;
                      });
                    },
            ),
            if (origen != null) ...[
              const SizedBox(height: 4),
              Text(
                'Disponible: ${origen.formattedAvailable}',
                style: GoogleFonts.dmSans(fontSize: 11, color: subtextColor),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('dropdown-destino'),
              decoration: const InputDecoration(
                labelText: 'Cuenta destino',
                border: OutlineInputBorder(),
              ),
              initialValue: _destinoId,
              items: [
                for (final c in destinos)
                  DropdownMenuItem<int>(
                    value: c.id,
                    child: Text(
                      _etiqueta(c),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _enviando
                  ? null
                  : (id) => setState(() {
                        _destinoId = id;
                        _error = null;
                      }),
              hint: Text(
                _origenId == null
                    ? 'Primero elija el origen'
                    : 'Elija la cuenta destino',
                style: TextStyle(color: subtextColor),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('campo-monto'),
              controller: _montoController,
              enabled: !_enviando,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('campo-glosa'),
              controller: _glosaController,
              enabled: !_enviando,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Glosa (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed:
                    _enviando ? null : () => _onTransferir(cuentas),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _enviando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Transferir',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'La transferencia es inmediata y sin comisiones.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 11, color: subtextColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoMensaje extends StatelessWidget {
  final String mensaje;
  final VoidCallback? onRetry;

  const _EstadoMensaje({required this.mensaje, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensaje, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
