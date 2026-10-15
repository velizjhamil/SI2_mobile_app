import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/cuenta_ahorro_model.dart';
import '../models/socio_model.dart';
import '../services/cuentas_service.dart';
import '../services/comprobantes_service.dart';
import '../services/notification_service.dart';
import '../services/socio_service.dart';
import 'comprobante_screen.dart';

class CuentaExtractosScreen extends StatefulWidget {
  final CuentasService? service;
  const CuentaExtractosScreen({super.key, this.service});
  @override
  State<CuentaExtractosScreen> createState() => _CuentaExtractosScreenState();
}

class _CuentaExtractosScreenState extends State<CuentaExtractosScreen> {
  late Future<CuentasResult> _future;
  @override
  void initState() {
    super.initState();
    _future = (widget.service ?? CuentasService()).listarMisCuentas();
  }

  @override
  Widget build(BuildContext context) => _Scaffold(
        title: 'Mis cuentas',
        child: FutureBuilder<CuentasResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final result = snapshot.data;
            if (result == null || !result.success) {
              return _Message(
                  result?.error ?? 'No se pudieron cargar tus cuentas');
            }
            if (result.cuentas.isEmpty) {
              return const _Message('No tienes cuentas disponibles.');
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: result.cuentas
                  .map((account) => Card(
                        child: ListTile(
                          title: Text(account.accountNumber),
                          subtitle: Text(account.formattedAvailable),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ExtractoScreen(accountId: account.id),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      );
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class ExtractoScreen extends StatefulWidget {
  final int accountId;
  final SocioService? service;
  final ComprobantesService? receiptsService;
  const ExtractoScreen({
    super.key,
    required this.accountId,
    this.service,
    this.receiptsService,
  });
  @override
  State<ExtractoScreen> createState() => _ExtractoScreenState();
}

class _ExtractoScreenState extends State<ExtractoScreen> {
  late Future<SocioResult<ExtractoCuenta>> _future;
  late final SocioService _service = widget.service ?? SocioService();
  late final ComprobantesService _receiptsService =
      widget.receiptsService ?? ComprobantesService();
  int _offset = 0;
  DateTime? _from;
  DateTime? _to;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _service.extracto(
      widget.accountId,
      from: _from == null ? null : _date(_from!),
      to: _to == null ? null : _date(_to!),
      offset: _offset,
    );
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: start
          ? (_from ?? DateTime.now().subtract(const Duration(days: 30)))
          : (_to ?? DateTime.now()),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _from = picked;
      } else {
        _to = picked;
      }
      _offset = 0;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) => _Scaffold(
        title: 'Extracto de cuenta',
        child: FutureBuilder<SocioResult<ExtractoCuenta>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final result = snapshot.data;
            if (result == null || !result.success) {
              return _Message(result?.error ?? 'No se pudo cargar el extracto',
                  retry: () => setState(_load));
            }
            final data = result.value!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(true),
                        child: Text(
                            'Desde: ${_from == null ? '30 días' : _date(_from!)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(false),
                        child:
                            Text('Hasta: ${_to == null ? 'hoy' : _date(_to!)}'),
                      ),
                    ),
                  ],
                ),
                Text('${data.from} — ${data.to}'),
                const SizedBox(height: 8),
                Text('Saldo inicial: ${data.openingBalance}'),
                Text(
                    'Créditos: ${data.totalCredits}   Débitos: ${data.totalDebits}'),
                Text('Saldo final: ${data.closingBalance}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                if (data.movements.isEmpty)
                  const Text('No hay movimientos en este rango.'),
                ...data.movements.map((m) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title:
                          Text(m.description.isEmpty ? m.type : m.description),
                      subtitle: Text('${m.date} · ${m.channel}'),
                      trailing: Text(
                          '${m.direction == 'DEBITO' ? '-' : '+'}${m.amount}\nSaldo ${m.resultingBalance}'),
                      onTap: m.receiptId == null
                          ? null
                          : () async {
                              final result =
                                  await _receiptsService.detail(m.receiptId!);
                              if (!mounted) return;
                              if (result.success && result.value != null) {
                                await Navigator.push(
                                  this.context,
                                  MaterialPageRoute(
                                    builder: (_) => ComprobanteScreen(
                                        comprobante: result.value!),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                      content: Text(result.error ??
                                          'No se pudo cargar el comprobante.')),
                                );
                              }
                            },
                    )),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _offset == 0
                          ? null
                          : () => setState(() {
                                _offset -= 50;
                                _load();
                              }),
                      child: const Text('Anterior'),
                    ),
                    Text('Total: ${data.total}'),
                    TextButton(
                      onPressed: data.movements.length < 50
                          ? null
                          : () => setState(() {
                                _offset += 50;
                                _load();
                              }),
                      child: const Text('Siguiente'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
}

class CreditosScreen extends StatefulWidget {
  final SocioService? service;
  final CuentasService? accountsService;
  const CreditosScreen({super.key, this.service, this.accountsService});

  @override
  State<CreditosScreen> createState() => _CreditosScreenState();
}

class _CreditosScreenState extends State<CreditosScreen> {
  late final SocioService _service = widget.service ?? SocioService();
  late final CuentasService _accountsService =
      widget.accountsService ?? CuentasService();
  late Future<SocioResult<List<SocioCredit>>> _future;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _future = _service.credits();
  }

  void _recargar() {
    setState(() {
      _future = _service.credits();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Will pass _hasChanges if needed
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.of(context).pop(_hasChanges),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CRÉDITOS Y CUOTAS',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: accentColor,
                ),
              ),
              Text(
                'Mis Créditos',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: accentColor),
              onPressed: _recargar,
              tooltip: 'Actualizar',
            ),
          ],
        ),
        body: FutureBuilder<SocioResult<List<SocioCredit>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final result = snapshot.data;
            if (result == null || !result.success) {
              return _Message(
                result?.error ?? 'No se pudieron cargar los créditos',
                retry: _recargar,
              );
            }
            final credits = result.value ?? [];
            if (credits.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.credit_card_off_outlined,
                          size: 56, color: subtextColor),
                      const SizedBox(height: 16),
                      Text(
                        'Sin créditos registrados',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Actualmente no tienes préstamos activos o registrados en tu cooperativa.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _recargar(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: credits.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final credit = credits[index];
                  final isVigente = credit.status.toUpperCase() == 'VIGENTE';
                  final hasNext = credit.nextInstallment != null;

                  return Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header: Código & Estado
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.account_balance_wallet_outlined,
                                  color: accentColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    credit.number.isEmpty
                                        ? credit.product
                                        : credit.number,
                                    style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    credit.product,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: subtextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isVigente
                                    ? (isDark
                                        ? const Color(0xFF1B382B)
                                        : const Color(0xFFE8F5E9))
                                    : (isDark
                                        ? const Color(0xFF352B1E)
                                        : const Color(0xFFFFF3E0)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                credit.status,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isVigente
                                      ? (isDark
                                          ? const Color(0xFF81C784)
                                          : const Color(0xFF2E7D32))
                                      : (isDark
                                          ? const Color(0xFFFFB74D)
                                          : const Color(0xFFEF6C00)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(height: 1, color: borderColor),
                        const SizedBox(height: 14),

                        // Métricas del crédito
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SALDO PENDIENTE',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      color: subtextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${credit.currency.isNotEmpty ? credit.currency : "Bs."} ${credit.outstandingBalance}',
                                    style: GoogleFonts.manrope(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MONTO APROBADO',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      color: subtextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${credit.currency.isNotEmpty ? credit.currency : "Bs."} ${credit.disbursedAmount}',
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: subtextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Tarjeta de Próxima Cuota
                        if (hasNext)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceHigh
                                  : AppColors.softGreen,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.forestGreen.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.schedule,
                                            size: 14,
                                            color: isDark
                                                ? AppColors.primary
                                                : AppColors.forestGreen),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Próxima cuota #${credit.nextInstallment!.number}',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? AppColors.primary
                                                : AppColors.forestGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Vence: ${credit.nextInstallment!.dueDate}',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkSubtext
                                            : AppColors.graphite,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${credit.currency.isNotEmpty ? credit.currency : "Bs."} ${credit.nextInstallment!.totalAmount}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? AppColors.darkText
                                            : AppColors.forestGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceHigh
                                  : const Color(0xFFF1F8E9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 18, color: Color(0xFF2E7D32)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Crédito al día: No hay cuotas pendientes',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 14),

                        // Botones de Acción
                        Row(
                          children: [
                            if (hasNext) ...[
                              Expanded(
                                flex: 3,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.forestGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.payment, size: 18),
                                  label: Text(
                                    'Pagar cuota',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final exito =
                                        await Navigator.of(context).push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) => PagoCreditoScreen(
                                          credit: credit,
                                          service: _service,
                                          accountsService: _accountsService,
                                        ),
                                      ),
                                    );
                                    if (exito == true) {
                                      _hasChanges = true;
                                      _recargar();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              flex: hasNext ? 3 : 1,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: textColor,
                                  side: BorderSide(color: borderColor),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.calendar_month,
                                    size: 18),
                                label: Text(
                                  hasNext
                                      ? 'Ver cuotas'
                                      : 'Ver cronograma de cuotas',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () async {
                                  final exito =
                                      await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CronogramaCreditoScreen(
                                        creditId: credit.id,
                                        credit: credit,
                                        service: _service,
                                        accountsService: _accountsService,
                                      ),
                                    ),
                                  );
                                  if (exito == true) {
                                    _hasChanges = true;
                                    _recargar();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class CreditoDetalleScreen extends StatelessWidget {
  final SocioCredit credit;
  final SocioService? service;
  final CuentasService? accountsService;
  const CreditoDetalleScreen(
      {super.key, required this.credit, this.service, this.accountsService});

  @override
  Widget build(BuildContext context) {
    return CronogramaCreditoScreen(
      creditId: credit.id,
      credit: credit,
      service: service,
      accountsService: accountsService,
    );
  }
}

class CronogramaCreditoScreen extends StatefulWidget {
  final int creditId;
  final SocioCredit? credit;
  final SocioService? service;
  final CuentasService? accountsService;

  const CronogramaCreditoScreen({
    super.key,
    required this.creditId,
    this.credit,
    this.service,
    this.accountsService,
  });

  @override
  State<CronogramaCreditoScreen> createState() =>
      _CronogramaCreditoScreenState();
}

class _CronogramaCreditoScreenState extends State<CronogramaCreditoScreen> {
  late final SocioService _service = widget.service ?? SocioService();
  late final CuentasService _accountsService =
      widget.accountsService ?? CuentasService();
  late Future<SocioResult<CreditSchedule>> _future;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _future = _service.creditSchedule(widget.creditId);
  }

  void _recargar() {
    setState(() {
      _future = _service.creditSchedule(widget.creditId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.of(context).pop(_hasChanges),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PLAN DE PAGOS',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: accentColor,
                ),
              ),
              Text(
                widget.credit?.number.isNotEmpty == true
                    ? 'Cuotas de ${widget.credit!.number}'
                    : 'Cronograma de Cuotas',
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
              icon: Icon(Icons.refresh, color: accentColor),
              onPressed: _recargar,
              tooltip: 'Actualizar cuotas',
            ),
          ],
        ),
        body: FutureBuilder<SocioResult<CreditSchedule>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final result = snapshot.data;
            if (result == null || !result.success) {
              return _Message(
                result?.error ?? 'No se pudo cargar el cronograma',
                retry: _recargar,
              );
            }
            final schedule = result.value!;
            final installments = schedule.installments;

            if (installments.isEmpty) {
              return const _Message('No hay cuotas para mostrar.');
            }

            final totalCuotas = installments.length;
            final pagadas = installments.where((i) => i.isPaid).length;
            final vencidas = installments.where((i) => i.isVencida).length;
            final pendientes = installments.where((i) => i.isPendiente).length;
            final creditData = schedule.credit;
            final currency = creditData['moneda']?.toString() ??
                widget.credit?.currency ??
                'Bs.';
            final saldoPendiente = creditData['saldo_pendiente']?.toString() ??
                widget.credit?.outstandingBalance ??
                '';

            return RefreshIndicator(
              onRefresh: () async => _recargar(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Resumen del Crédito & Progreso
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progreso de Amortización',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '$pagadas de $totalCuotas pagadas',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalCuotas > 0
                                ? (pagadas / totalCuotas).clamp(0.0, 1.0)
                                : 0.0,
                            minHeight: 8,
                            backgroundColor:
                                accentColor.withValues(alpha: 0.15),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            _miniBadge(
                                'PAGADAS', '$pagadas', const Color(0xFF2E7D32), isDark),
                            _miniBadge(
                                'VENCIDAS', '$vencidas', const Color(0xFFC62828), isDark),
                            _miniBadge(
                                'PENDIENTES', '$pendientes', const Color(0xFF1565C0), isDark),
                            if (saldoPendiente.isNotEmpty)
                              _miniBadge('SALDO RESTANTE',
                                  '$currency $saldoPendiente', textColor, isDark),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Alerta de mora si hay cuotas vencidas
                  if (vencidas > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF381E1E)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFEF5350).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFD32F2F), size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tienes $vencidas cuota(s) vencida(s). Paga a tiempo para evitar recargos e intereses adicionales por mora.',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFFFFCDD2)
                                    : const Color(0xFFB71C1C),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Text(
                    'LISTA DE CUOTAS',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Lista detallada de cuotas
                  for (final item in installments) ...[
                    _buildCuotaCard(
                      context,
                      item: item,
                      currency: currency,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      accentColor: accentColor,
                      onPay: () async {
                        final creditObj = widget.credit ??
                            SocioCredit(
                              id: widget.creditId,
                              number: creditData['numero_credito']?.toString() ?? '',
                              product: creditData['producto']?.toString() ?? 'Crédito',
                              currency: currency,
                              disbursedAmount: '0.00',
                              outstandingBalance: saldoPendiente,
                              status: creditData['estado']?.toString() ?? 'VIGENTE',
                              nextInstallment: CreditInstallment(
                                number: item.number,
                                dueDate: item.dueDate,
                                totalAmount: item.totalAmount,
                              ),
                            );

                        final exito = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => PagoCreditoScreen(
                              credit: creditObj,
                              cuota: item,
                              service: _service,
                              accountsService: _accountsService,
                            ),
                          ),
                        );
                        if (exito == true) {
                          _hasChanges = true;
                          _recargar();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _miniBadge(
      String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildCuotaCard(
    BuildContext context, {
    required CreditScheduleItem item,
    required String currency,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required Color accentColor,
    required VoidCallback onPay,
  }) {
    Color statusBg;
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (item.isPaid) {
      statusBg =
          isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9);
      statusColor =
          isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'PAGADA';
    } else if (item.isVencida) {
      statusBg =
          isDark ? const Color(0xFF3E1F24) : const Color(0xFFFFEBEE);
      statusColor =
          isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828);
      statusIcon = Icons.error_outline_rounded;
      statusLabel = 'VENCIDA';
    } else {
      statusBg =
          isDark ? const Color(0xFF1E2838) : const Color(0xFFE3F2FD);
      statusColor =
          isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
      statusIcon = Icons.schedule_rounded;
      statusLabel = 'PENDIENTE';
    }

    final moraNum = double.tryParse(item.mora) ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isVencida
              ? const Color(0xFFEF5350).withValues(alpha: 0.5)
              : (item.isPaid
                  ? const Color(0xFF81C784).withValues(alpha: 0.3)
                  : borderColor),
          width: item.isVencida ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cuota # + Badge de Estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cuota #${item.number}',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 13, color: subtextColor),
              const SizedBox(width: 4),
              Text(
                'Vence: ${item.dueDate}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: item.isVencida
                      ? const Color(0xFFEF5350)
                      : subtextColor,
                  fontWeight: item.isVencida ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (item.isPaid && item.paymentDate.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('·', style: TextStyle(color: subtextColor)),
                const SizedBox(width: 8),
                Text(
                  'Pagada: ${item.paymentDate.split("T").first}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Desglose: Capital, Interés, Seguro, Mora
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceHigh
                  : AppColors.lightSurfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _desgloseRow('Capital amortizado:', '$currency ${item.capital}',
                    textColor, subtextColor),
                const SizedBox(height: 4),
                _desgloseRow('Interés cuota:', '$currency ${item.interest}',
                    textColor, subtextColor),
                const SizedBox(height: 4),
                _desgloseRow('Seguro / Cargos:', '$currency ${item.insurance}',
                    textColor, subtextColor),
                if (moraNum > 0) ...[
                  const SizedBox(height: 4),
                  _desgloseRow('Mora acumulada:', '$currency ${item.mora}',
                      const Color(0xFFE53935), const Color(0xFFE53935)),
                ],
                const SizedBox(height: 4),
                _desgloseRow('Saldo capital restante:',
                    '$currency ${item.capitalBalance}', textColor, subtextColor),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Monto total & Botón pagar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL CUOTA',
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: subtextColor,
                    ),
                  ),
                  Text(
                    '$currency ${item.totalAmount}',
                    style: GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: item.isVencida
                          ? const Color(0xFFEF5350)
                          : (item.isPaid ? textColor : accentColor),
                    ),
                  ),
                ],
              ),
              if (!item.isPaid)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: item.isVencida
                        ? const Color(0xFFC62828)
                        : AppColors.forestGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.payment, size: 16),
                  label: Text(
                    'Pagar cuota',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: onPay,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desgloseRow(
      String label, String value, Color textColor, Color subtextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, color: subtextColor),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class PagoCreditoScreen extends StatefulWidget {
  final SocioCredit credit;
  final CreditScheduleItem? cuota;
  final SocioService service;
  final CuentasService? accountsService;

  const PagoCreditoScreen({
    super.key,
    required this.credit,
    this.cuota,
    required this.service,
    this.accountsService,
  });

  @override
  State<PagoCreditoScreen> createState() => _PagoCreditoScreenState();
}

class _PagoCreditoScreenState extends State<PagoCreditoScreen> {
  late Future<CuentasResult> _future;
  int? _accountId;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _future = (widget.accountsService ?? CuentasService()).listarMisCuentas();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = isDark ? AppColors.primary : AppColors.forestGreen;

    final cuotaNum = widget.cuota?.number ??
        widget.credit.nextInstallment?.number ??
        1;
    final cuotaMontoStr = widget.cuota?.totalAmount ??
        widget.credit.nextInstallment?.totalAmount ??
        '0.00';
    final cuotaMonto =
        double.tryParse(cuotaMontoStr.replaceAll(',', '').trim()) ?? 0.0;
    final currency = widget.credit.currency.isNotEmpty
        ? widget.credit.currency
        : 'Bs.';

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
              'PAGO MÓVIL DE CUOTA',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: accentColor,
              ),
            ),
            Text(
              'Confirmar Pago',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<CuentasResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data == null || !snapshot.data!.success) {
            return _Message(
              snapshot.data?.error ?? 'No se pudieron cargar tus cuentas',
              retry: () => setState(() {
                _future = (widget.accountsService ?? CuentasService())
                    .listarMisCuentas();
              }),
            );
          }

          final allAccounts = snapshot.data!.cuentas;
          final activeAccounts =
              allAccounts.where((a) => a.status == 'ACTIVA').toList();

          if (activeAccounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_outlined,
                        size: 48, color: subtextColor),
                    const SizedBox(height: 12),
                    Text(
                      'No tienes cuentas de ahorro activas disponibles para realizar el débito.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: textColor),
                    ),
                  ],
                ),
              ),
            );
          }

          _accountId ??= activeAccounts.first.id;
          final selectedAccount = activeAccounts.firstWhere(
            (a) => a.id == _accountId,
            orElse: () => activeAccounts.first,
          );

          final hasSufficientBalance =
              selectedAccount.availableBalance >= cuotaMonto;
          final balanceDifference =
              selectedAccount.availableBalance - cuotaMonto;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Resumen de la Cuota a Pagar
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detalle de la Cuota',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: subtextColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Cuota #$cuotaNum',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.credit.number.isNotEmpty
                          ? '${widget.credit.number} · ${widget.credit.product}'
                          : widget.credit.product,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (widget.cuota != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Capital:',
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, color: subtextColor)),
                          Text('$currency ${widget.cuota!.capital}',
                              style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Interés:',
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, color: subtextColor)),
                          Text('$currency ${widget.cuota!.interest}',
                              style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textColor)),
                        ],
                      ),
                      if (double.tryParse(widget.cuota!.mora) != null &&
                          double.parse(widget.cuota!.mora) > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Mora:',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: const Color(0xFFE53935))),
                            Text('$currency ${widget.cuota!.mora}',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE53935))),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 10),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Monto total a debitar:',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '$currency $cuotaMontoStr',
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Selector de Cuenta de Ahorro Origen
              Text(
                'CUENTA DE DÉBITO',
                style: GoogleFonts.dmSans(
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _accountId,
                    isExpanded: true,
                    dropdownColor: cardBg,
                    items: activeAccounts.map((account) {
                      return DropdownMenuItem<int>(
                        value: account.id,
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    account.accountNumber,
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    account.productType,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      color: subtextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              account.formattedAvailable,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _saving
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() {
                                _accountId = val;
                                _errorMessage = null;
                              });
                            }
                          },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3. Indicador de Validación de Saldo
              if (!hasSufficientBalance)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF381E1E)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEF5350).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFC62828), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saldo insuficiente',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFC62828),
                              ),
                            ),
                            Text(
                              'La cuenta seleccionada cuenta con ${selectedAccount.formattedAvailable}, monto menor al total de la cuota ($currency $cuotaMontoStr).',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFFFFCDD2)
                                    : const Color(0xFFB71C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1B382B)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF81C784).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Color(0xFF2E7D32), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saldo disponible suficiente',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                            Text(
                              'Saldo restante estimado tras el pago: ${selectedAccount.currency.symbol} ${balanceDifference.toStringAsFixed(2)}',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFFA5D6A7)
                                    : const Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: const Color(0xFFC62828),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 4. Botón de Confirmación
              ElevatedButton(
                key: const Key('btn-confirmar-pago-cuota'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? Colors.white10
                      : Colors.black12,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (_saving || !hasSufficientBalance)
                    ? null
                    : () => _confirmAndPay(
                          cuotaNum: cuotaNum,
                          cuotaMonto: cuotaMonto,
                          cuotaMontoStr: cuotaMontoStr,
                          currency: currency,
                          selectedAccount: selectedAccount,
                        ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Confirmar Pago de Cuota',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmAndPay({
    required int cuotaNum,
    required double cuotaMonto,
    required String cuotaMontoStr,
    required String currency,
    required CuentaAhorro selectedAccount,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          'Confirmar Pago de Cuota',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Deseas confirmar el pago de la cuota #$cuotaNum con débito real de tu cuenta?',
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monto a debitar: $currency $cuotaMontoStr',
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.bold,
                          color: AppColors.forestGreen)),
                  Text('Cuenta débito: ${selectedAccount.accountNumber}',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.graphite)),
                  Text(
                      'Crédito: ${widget.credit.number.isNotEmpty ? widget.credit.number : widget.credit.product}',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.graphite)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Sí, Pagar'),
          ),
        ],
      ),
    );

    if (confirmed != true || _accountId == null) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final result = await widget.service.payCredit(
      widget.credit.id,
      _accountId!,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      // Disparar notificación local e in-app
      try {
        Provider.of<NotificationProvider>(context, listen: false)
            .notifyCreditPayment(
          monto: cuotaMonto,
          moneda: selectedAccount.currency.symbol.isNotEmpty
              ? selectedAccount.currency.symbol
              : currency,
          cuentaNumero: selectedAccount.accountNumber,
          cuotaNumero: cuotaNum,
          creditoNumero: widget.credit.number.isNotEmpty
              ? widget.credit.number
              : widget.credit.product,
          context: context,
        );
      } catch (_) {}

      // Mostrar Comprobante Digital
      if (result.value?.comprobante != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComprobanteScreen(
              comprobante: result.value!.comprobante!,
            ),
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago de cuota realizado con éxito.'),
            backgroundColor: Color(0xFF1E6B3E),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _errorMessage = result.error ?? 'No se pudo procesar el pago.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    }
  }
}

class DpfScreen extends StatelessWidget {
  final SocioService? service;
  const DpfScreen({super.key, this.service});
  @override
  Widget build(BuildContext context) => _Scaffold(
      title: 'Mis DPF',
      child: FutureBuilder<SocioResult<List<Dpf>>>(
          future: (service ?? SocioService()).dpfs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final result = snapshot.data;
            if (result == null || !result.success) {
              return _Message(result?.error ?? 'No se pudieron cargar tus DPF');
            }
            if (result.value!.isEmpty) {
              return const _Message('No tienes DPF registrados.');
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: result.value!.map((dpf) {
                return Card(
                  child: ListTile(
                    title: Text(dpf.certificateNumber),
                    subtitle: Text(
                        '${dpf.amount} ${dpf.currency} · Vence ${dpf.maturityDate}'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DpfDetailScreen(dpf: dpf, service: service),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }));
}

class DpfDetailScreen extends StatelessWidget {
  final Dpf dpf;
  final SocioService? service;
  const DpfDetailScreen({super.key, required this.dpf, this.service});
  @override
  Widget build(BuildContext context) => _Scaffold(
      title: 'Detalle del DPF',
      child: FutureBuilder<SocioResult<Dpf>>(
          future: dpf.schedule.isNotEmpty
              ? Future.value(SocioResult.success(dpf))
              : (service ?? SocioService()).dpfDetail(dpf.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final result = snapshot.data;
            if (result == null || !result.success) {
              return _Message(result?.error ?? 'No se pudo cargar el detalle');
            }
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('${result.value!.amount} ${result.value!.currency}'),
              Text('Tasa: ${result.value!.interestRate}'),
              const Divider(),
              ...result.value!.schedule.map((i) => ListTile(
                  title: Text('Pago ${i.number} · ${i.status}'),
                  subtitle: Text(i.paymentDate),
                  trailing: Text(i.netInterest)))
            ]);
          }));
}

class RecreditosScreen extends StatefulWidget {
  final SocioService? service;
  const RecreditosScreen({super.key, this.service});
  @override
  State<RecreditosScreen> createState() => _RecreditosScreenState();
}

class _RecreditosScreenState extends State<RecreditosScreen> {
  late Future<SocioResult<List<RecreditOffer>>> _future;
  late final SocioService _service = widget.service ?? SocioService();
  @override
  void initState() {
    super.initState();
    _future = _service.offers();
  }

  @override
  Widget build(BuildContext context) => _Scaffold(
      title: 'Ofertas de re-crédito',
      child: FutureBuilder<SocioResult<List<RecreditOffer>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final result = snapshot.data;
            if (result == null || !result.success) {
              return _Message(
                  result?.error ?? 'No se pudieron cargar las ofertas',
                  retry: () => setState(() => _future = _service.offers()));
            }
            if (result.value!.isEmpty) {
              return const _Message('No tienes ofertas vigentes.');
            }
            return ListView(
                padding: const EdgeInsets.all(16),
                children: result.value!
                    .map((offer) => Card(
                        child: ListTile(
                            title: Text('Oferta ${offer.id}'),
                            subtitle: Text(
                                '${offer.amount} · ${offer.termMonths} meses'),
                            trailing: PopupMenuButton<String>(
                                onSelected: (value) => value == 'accept'
                                    ? _accept(offer)
                                    : _discard(offer),
                                itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'accept',
                                          child: Text('Aceptar')),
                                      PopupMenuItem(
                                          value: 'discard',
                                          child: Text('Descartar'))
                                    ]))))
                    .toList());
          }));
  Future<void> _accept(RecreditOffer offer) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Confirmar aceptación'),
                content: const Text(
                    '¿Deseas aceptar esta oferta y generar una solicitud de crédito?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Confirmar'))
                ]));
    if (confirmed != true) return;
    final result = await _service.acceptOffer(offer.id);
    if (!mounted) return;
    if (result.success) {
      final refreshedOffers = _service.offers();
      setState(() {
        _future = refreshedOffers;
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.success ? 'Oferta aceptada.' : result.error!)));
    }
  }

  Future<void> _discard(RecreditOffer offer) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Descartar oferta'),
                content: const Text('¿Deseas descartar esta oferta?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Descartar'))
                ]));
    if (confirmed != true) return;
    final result = await _service.discardOffer(offer.id);
    if (!mounted) return;
    if (result.success) {
      final refreshedOffers = _service.offers();
      setState(() {
        _future = refreshedOffers;
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(result.success ? 'Oferta descartada.' : result.error!)));
    }
  }
}

class _Scaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _Scaffold({required this.title, required this.child});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)), body: child);
}

class _Message extends StatelessWidget {
  final String message;
  final VoidCallback? retry;
  const _Message(this.message, {this.retry});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            if (retry != null)
              TextButton(onPressed: retry, child: const Text('Reintentar'))
          ])));
}
