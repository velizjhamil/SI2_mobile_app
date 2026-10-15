import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/cuenta_ahorro_model.dart';
import '../models/socio_model.dart';
import '../services/comprobantes_service.dart';
import '../services/cuentas_service.dart';
import '../services/notification_service.dart';
import '../services/socio_service.dart';
import 'comprobante_screen.dart';
import 'transferencia_screen.dart';

class SaldosExtractosScreen extends StatefulWidget {
  final int? initialAccountId;
  final CuentasService? cuentasService;
  final SocioService? socioService;

  const SaldosExtractosScreen({
    super.key,
    this.initialAccountId,
    this.cuentasService,
    this.socioService,
  });

  @override
  State<SaldosExtractosScreen> createState() => _SaldosExtractosScreenState();
}

class _SaldosExtractosScreenState extends State<SaldosExtractosScreen> {
  late final CuentasService _cuentasService =
      widget.cuentasService ?? CuentasService();
  late final SocioService _socioService =
      widget.socioService ?? SocioService();

  List<CuentaAhorro> _cuentas = [];
  CuentaAhorro? _selectedCuenta;
  bool _loadingCuentas = true;
  String? _cuentasError;

  ExtractoCuenta? _extracto;
  bool _loadingExtracto = false;
  String? _extractoError;

  // Filtros
  String _filtroTipo = 'TODOS'; // 'TODOS', 'INGRESOS', 'EGRESOS'
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCuentas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCuentas() async {
    setState(() {
      _loadingCuentas = true;
      _cuentasError = null;
    });

    final res = await _cuentasService.listarMisCuentas();
    if (!mounted) return;

    if (!res.success) {
      setState(() {
        _loadingCuentas = false;
        _cuentasError = res.error ?? 'No se pudieron cargar las cuentas';
      });
      return;
    }

    setState(() {
      _loadingCuentas = false;
      _cuentas = res.cuentas;
      if (_cuentas.isNotEmpty) {
        if (widget.initialAccountId != null) {
          _selectedCuenta = _cuentas.firstWhere(
            (c) => c.id == widget.initialAccountId,
            orElse: () => _cuentas.first,
          );
        } else {
          _selectedCuenta = _cuentas.first;
        }
      }
    });

    if (_selectedCuenta != null) {
      _loadExtracto();
    }
  }

  Future<void> _loadExtracto() async {
    if (_selectedCuenta == null) return;
    setState(() {
      _loadingExtracto = true;
      _extractoError = null;
    });

    final fromStr = _fechaDesde != null ? _formatDate(_fechaDesde!) : null;
    final toStr = _fechaHasta != null ? _formatDate(_fechaHasta!) : null;

    final res = await _socioService.extracto(
      _selectedCuenta!.id,
      from: fromStr,
      to: toStr,
      limit: 100,
    );

    if (!mounted) return;
    setState(() {
      _loadingExtracto = false;
      if (res.success) {
        _extracto = res.value;
      } else {
        _extractoError = res.error ?? 'No se pudo cargar el extracto';
      }
    });
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _onSelectCuenta(CuentaAhorro cuenta) {
    if (_selectedCuenta?.id == cuenta.id) return;
    setState(() {
      _selectedCuenta = cuenta;
    });
    _loadExtracto();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _fechaDesde != null && _fechaHasta != null
          ? DateTimeRange(start: _fechaDesde!, end: _fechaHasta!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
    );
    if (picked != null) {
      setState(() {
        _fechaDesde = picked.start;
        _fechaHasta = picked.end;
      });
      _loadExtracto();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _fechaDesde = null;
      _fechaHasta = null;
    });
    _loadExtracto();
  }

  Future<void> _showDepositDialog() async {
    if (_selectedCuenta == null) return;
    final amountController = TextEditingController();
    final conceptController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final sheetBg = isDark ? const Color(0xFF1E2420) : Colors.white;
          final textColor = isDark ? Colors.white : const Color(0xFF101412);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Depositar en Cuenta',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cuenta destino: ${_selectedCuenta!.accountNumber} (${_selectedCuenta!.currency.currencyCode})',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Monto a depositar',
                        prefixText: '${_selectedCuenta!.currency.symbol} ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Ingresa un monto';
                        }
                        final num = double.tryParse(val.trim());
                        if (num == null || num <= 0) {
                          return 'Ingresa un monto válido mayor a 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: conceptController,
                      decoration: InputDecoration(
                        labelText: 'Concepto (Opcional)',
                        hintText: 'Ej. Ahorro quincenal',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forestGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheetState(() => isSubmitting = true);
                                final monto =
                                    double.parse(amountController.text.trim());

                                final res = await _socioService.deposit(
                                  accountId: _selectedCuenta!.id,
                                  amount: monto,
                                  concept: conceptController.text.trim().isEmpty
                                      ? null
                                      : conceptController.text.trim(),
                                );

                                if (!ctx.mounted) return;

                                if (res.success) {
                                  Navigator.pop(ctx);
                                  // Disparar notificación reactiva
                                  final notif =
                                      Provider.of<NotificationProvider>(
                                    ctx,
                                    listen: false,
                                  );
                                  notif.addNotification(
                                    title: '¡Depósito Exitoso!',
                                    message:
                                        'Se han depositado +${_selectedCuenta!.currency.symbol} ${monto.toStringAsFixed(2)} en tu cuenta ${_selectedCuenta!.accountNumber}',
                                    type: NotificationType.ingreso,
                                    accountNumber:
                                        _selectedCuenta!.accountNumber,
                                    amount: monto.toStringAsFixed(2),
                                    context: ctx,
                                  );

                                  // Recargar cuentas y extractos
                                  _loadCuentas();
                                } else {
                                  setSheetState(() => isSubmitting = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(res.error ??
                                          'Error al realizar el depósito'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'CONFIRMAR DEPÓSITO',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    amountController.dispose();
    conceptController.dispose();
  }

  Future<void> _showMovementDetail(ExtractoMovimiento mov) async {
    if (mov.receiptId != null) {
      final res = await ComprobantesService().detail(mov.receiptId!);
      if (!mounted) return;
      if (res.success && res.value != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComprobanteScreen(comprobante: res.value!),
          ),
        );
        return;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2420) : Colors.white;
    final isIngreso = mov.direction == 'CREDITO';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isIngreso ? const Color(0xFF27AE60) : const Color(0xFFE74C3C))
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIngreso
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: isIngreso
                        ? const Color(0xFF27AE60)
                        : const Color(0xFFE74C3C),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mov.description,
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Transacción #${mov.transactionId}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _buildDetailRow('Monto:',
                '${isIngreso ? '+' : '-'}${_selectedCuenta?.currency.symbol ?? ''} ${mov.amount}'),
            _buildDetailRow('Saldo Resultante:',
                '${_selectedCuenta?.currency.symbol ?? ''} ${mov.resultingBalance}'),
            _buildDetailRow('Fecha y Hora:', mov.date.replaceFirst('T', ' ')),
            _buildDetailRow('Canal:', mov.channel),
            _buildDetailRow('Sentido:', mov.direction),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('CERRAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Saldos & Extractos',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: () {
              _loadCuentas();
            },
          ),
        ],
      ),
      body: _loadingCuentas
          ? const Center(child: CircularProgressIndicator())
          : _cuentasError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(_cuentasError!, style: TextStyle(color: textColor)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadCuentas,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _cuentas.isEmpty
                  ? Center(
                      child: Text(
                        'No tienes cuentas de ahorro activas',
                        style: TextStyle(color: textColor),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadCuentas();
                      },
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        children: [
                          // 1. Selector Horizontal de Cuentas
                          Text(
                            'SELECCIONA UNA CUENTA',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: subtextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 120,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _cuentas.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final cuenta = _cuentas[index];
                                final isSelected =
                                    cuenta.id == _selectedCuenta?.id;

                                return GestureDetector(
                                  onTap: () => _onSelectCuenta(cuenta),
                                  child: Container(
                                    width: 220,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.forestGreen
                                          : cardBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.forestGreen
                                            : borderColor,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: AppColors.forestGreen
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              cuenta.productType,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Colors.white70
                                                    : subtextColor,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? Colors.white.withValues(alpha: 0.2)
                                                    : AppColors.forestGreen
                                                        .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                cuenta.currency.currencyCode,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : AppColors.forestGreen,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          cuenta.accountNumber,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                            color: isSelected
                                                ? Colors.white
                                                : textColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          cuenta.formattedAvailable,
                                          style: GoogleFonts.manrope(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected
                                                ? Colors.white
                                                : textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Botones de Operación sobre la cuenta seleccionada
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.add_circle_outline,
                                      size: 18),
                                  label: const Text('DEPOSITAR'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.forestGreen,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _showDepositDialog,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.swap_horiz, size: 18),
                                  label: const Text('TRANSFERIR'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.forestGreen,
                                    side: const BorderSide(
                                        color: AppColors.forestGreen),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final exito =
                                        await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const TransferenciaScreen(),
                                      ),
                                    );
                                    if (exito == true) {
                                      _loadCuentas();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 3. Cabecera del Extracto y Filtros
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'MOVIMIENTOS DE LA CUENTA',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: subtextColor,
                                ),
                              ),
                              InkWell(
                                onTap: _pickDateRange,
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 13,
                                        color: _fechaDesde != null
                                            ? AppColors.forestGreen
                                            : subtextColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      _fechaDesde != null
                                          ? '${_fechaDesde!.day}/${_fechaDesde!.month} - ${_fechaHasta!.day}/${_fechaHasta!.month}'
                                          : 'Filtrar fechas',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _fechaDesde != null
                                            ? AppColors.forestGreen
                                            : subtextColor,
                                      ),
                                    ),
                                    if (_fechaDesde != null) ...[
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: _clearDateFilter,
                                        child: const Icon(Icons.close,
                                            size: 14, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Barra de búsqueda por texto / concepto
                          TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim().toLowerCase();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Buscar por concepto o tipo...',
                              hintStyle: TextStyle(
                                  fontSize: 12, color: subtextColor),
                              prefixIcon:
                                  const Icon(Icons.search, size: 18),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              filled: true,
                              fillColor: cardBg,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Chips de Filtro (Todos / Ingresos / Egresos)
                          Row(
                            children: [
                              _buildFilterChip('TODOS', 'Todos'),
                              const SizedBox(width: 8),
                              _buildFilterChip('INGRESOS', 'Ingresos (+)'),
                              const SizedBox(width: 8),
                              _buildFilterChip('EGRESOS', 'Egresos (-)'),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 4. Contenido del Extracto
                          if (_loadingExtracto)
                            const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Center(
                                  child: CircularProgressIndicator()),
                            )
                          else if (_extractoError != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(_extractoError!,
                                    style: TextStyle(color: subtextColor)),
                              ),
                            )
                          else if (_extracto == null ||
                              _extracto!.movements.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Center(
                                child: Text(
                                  'No hay movimientos registrados en este período',
                                  style: TextStyle(color: subtextColor),
                                ),
                              ),
                            )
                          else ...[
                            // Resumen de saldos del extracto
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSummaryItem(
                                      'Ingresos (+)',
                                      _extracto!.totalCredits,
                                      const Color(0xFF27AE60)),
                                  _buildSummaryItem(
                                      'Egresos (-)',
                                      _extracto!.totalDebits,
                                      const Color(0xFFE74C3C)),
                                  _buildSummaryItem('Saldo Final',
                                      _extracto!.closingBalance, textColor),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Lista de Movimientos filtrados
                            ..._buildMovementsList(textColor, subtextColor,
                                cardBg, borderColor),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filtroTipo == key;
    return GestureDetector(
      onTap: () {
        setState(() => _filtroTipo = key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.forestGreen
              : AppColors.forestGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.forestGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMovementsList(Color textColor, Color subtextColor,
      Color cardBg, Color borderColor) {
    final symbol = _selectedCuenta?.currency.symbol ?? 'Bs.';

    var list = _extracto!.movements;

    // Filtro por tipo
    if (_filtroTipo == 'INGRESOS') {
      list = list.where((m) => m.direction == 'CREDITO').toList();
    } else if (_filtroTipo == 'EGRESOS') {
      list = list.where((m) => m.direction == 'DEBITO').toList();
    }

    // Filtro por búsqueda
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((m) =>
              m.description.toLowerCase().contains(_searchQuery) ||
              m.type.toLowerCase().contains(_searchQuery) ||
              m.amount.contains(_searchQuery))
          .toList();
    }

    if (list.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text('No hay movimientos que coincidan con el filtro',
                style: TextStyle(color: subtextColor)),
          ),
        )
      ];
    }

    return list.map((mov) {
      final isIngreso = mov.direction == 'CREDITO';
      final formattedAmount =
          '${isIngreso ? '+' : '-'}$symbol ${mov.amount}';

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: ListTile(
          onTap: () => _showMovementDetail(mov),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isIngreso
                      ? const Color(0xFF27AE60)
                      : const Color(0xFFE74C3C))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIngreso
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isIngreso
                  ? const Color(0xFF27AE60)
                  : const Color(0xFFE74C3C),
              size: 20,
            ),
          ),
          title: Text(
            mov.description,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          subtitle: Text(
            '${mov.channel} • ${mov.date.replaceFirst('T', ' ').substring(0, 16)}',
            style: TextStyle(fontSize: 10, color: subtextColor),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedAmount,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isIngreso
                      ? const Color(0xFF27AE60)
                      : const Color(0xFFE74C3C),
                ),
              ),
              Text(
                'Saldo: $symbol ${mov.resultingBalance}',
                style: TextStyle(fontSize: 10, color: subtextColor),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
