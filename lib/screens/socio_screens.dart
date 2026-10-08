import 'package:flutter/material.dart';

import '../models/socio_model.dart';
import '../services/cuentas_service.dart';
import '../services/comprobantes_service.dart';
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
            if (result.cuentas.isEmpty)
              return const _Message('No tienes cuentas disponibles.');
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
  late Future<SocioResult<List<SocioCredit>>> _future;
  @override
  void initState() {
    super.initState();
    _future = _service.credits();
  }

  @override
  Widget build(BuildContext context) => _Scaffold(
        title: 'Mis créditos',
        child: FutureBuilder<SocioResult<List<SocioCredit>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            final result = snapshot.data;
            if (result == null || !result.success)
              return _Message(
                  result?.error ?? 'No se pudieron cargar los créditos',
                  retry: () => setState(() => _future = _service.credits()));
            if (result.value!.isEmpty)
              return const _Message('No tienes créditos registrados.');
            return ListView(
              padding: const EdgeInsets.all(16),
              children: result.value!
                  .map((credit) => Card(
                        child: ListTile(
                          title: Text(credit.number.isEmpty
                              ? credit.product
                              : credit.number),
                          subtitle: Text(
                              'Saldo pendiente: ${credit.outstandingBalance}\n${credit.nextInstallment == null ? 'Sin próxima cuota' : 'Próxima cuota: ${credit.nextInstallment!.totalAmount} · ${credit.nextInstallment!.dueDate}'}'),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CreditoDetalleScreen(
                                      credit: credit,
                                      service: _service,
                                      accountsService:
                                          widget.accountsService))),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      );
}

class CreditoDetalleScreen extends StatelessWidget {
  final SocioCredit credit;
  final SocioService? service;
  final CuentasService? accountsService;
  const CreditoDetalleScreen(
      {super.key, required this.credit, this.service, this.accountsService});
  @override
  Widget build(BuildContext context) => _Scaffold(
        title: 'Detalle del crédito',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(credit.product,
                style: Theme.of(context).textTheme.headlineSmall),
            Text('Saldo pendiente: ${credit.outstandingBalance}'),
            if (credit.nextInstallment != null)
              Text('Próxima cuota: ${credit.nextInstallment!.totalAmount}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PagoCreditoScreen(
                          credit: credit,
                          service: service ?? SocioService(),
                          accountsService: accountsService))),
              child: const Text('Pagar próxima cuota'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CronogramaCreditoScreen(
                          creditId: credit.id, service: service))),
              child: const Text('Ver cronograma'),
            ),
          ],
        ),
      );
}

class PagoCreditoScreen extends StatefulWidget {
  final SocioCredit credit;
  final SocioService service;
  final CuentasService? accountsService;
  const PagoCreditoScreen(
      {super.key,
      required this.credit,
      required this.service,
      this.accountsService});
  @override
  State<PagoCreditoScreen> createState() => _PagoCreditoScreenState();
}

class _PagoCreditoScreenState extends State<PagoCreditoScreen> {
  late Future<CuentasResult> _future;
  int? _accountId;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _future = (widget.accountsService ?? CuentasService()).listarMisCuentas();
  }

  @override
  Widget build(BuildContext context) => _Scaffold(
        title: 'Pagar cuota',
        child: FutureBuilder<CuentasResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.data == null || !snapshot.data!.success)
              return _Message(
                  snapshot.data?.error ?? 'No se pudieron cargar tus cuentas');
            final accounts = snapshot.data!.cuentas;
            if (accounts.isEmpty)
              return const _Message('No tienes cuentas propias disponibles.');
            _accountId ??= accounts.first.id;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        'Cuota a pagar: ${widget.credit.nextInstallment?.totalAmount ?? 'Consultar deuda'}'),
                    DropdownButton<int>(
                        value: _accountId,
                        isExpanded: true,
                        items: accounts
                            .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(
                                    '${a.accountNumber} · ${a.formattedAvailable}')))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _accountId = value)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: _saving ? null : _pay,
                        child:
                            Text(_saving ? 'Procesando...' : 'Confirmar pago')),
                  ]),
            );
          },
        ),
      );
  Future<void> _pay() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Confirmar pago'),
                content: const Text(
                    '¿Deseas pagar la próxima cuota desde esta cuenta?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Confirmar'))
                ]));
    if (confirmed != true || _accountId == null) return;
    setState(() => _saving = true);
    final result =
        await widget.service.payCredit(widget.credit.id, _accountId!);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            result.success ? 'Pago realizado correctamente.' : result.error!)));
    if (result.success && result.value?.comprobante != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ComprobanteScreen(comprobante: result.value!.comprobante!),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } else if (result.success) {
      Navigator.pop(context, true);
    }
  }
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class CronogramaCreditoScreen extends StatelessWidget {
  final int creditId;
  final SocioService? service;
  const CronogramaCreditoScreen(
      {super.key, required this.creditId, this.service});
  @override
  Widget build(BuildContext context) => _Scaffold(
      title: 'Cronograma de crédito',
      child: FutureBuilder<SocioResult<CreditSchedule>>(
          future: (service ?? SocioService()).creditSchedule(creditId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            final result = snapshot.data;
            if (result == null || !result.success)
              return _Message(
                  result?.error ?? 'No se pudo cargar el cronograma');
            if (result.value!.installments.isEmpty)
              return const _Message('No hay cuotas para mostrar.');
            return ListView(
                children: result.value!.installments
                    .map((i) => ListTile(
                        title: Text('Cuota ${i.number} · ${i.status}'),
                        subtitle: Text(
                            'Vence: ${i.dueDate} · Capital: ${i.capital} · Interés: ${i.interest}'),
                        trailing: Text(i.totalAmount)))
                    .toList());
          }));
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
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            final result = snapshot.data;
            if (result == null || !result.success)
              return _Message(result?.error ?? 'No se pudieron cargar tus DPF');
            if (result.value!.isEmpty)
              return const _Message('No tienes DPF registrados.');
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
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            final result = snapshot.data;
            if (result == null || !result.success)
              return _Message(result?.error ?? 'No se pudo cargar el detalle');
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
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            final result = snapshot.data;
            if (result == null || !result.success)
              return _Message(
                  result?.error ?? 'No se pudieron cargar las ofertas',
                  retry: () => setState(() => _future = _service.offers()));
            if (result.value!.isEmpty)
              return const _Message('No tienes ofertas vigentes.');
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
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.success ? 'Oferta aceptada.' : result.error!)));
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
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(result.success ? 'Oferta descartada.' : result.error!)));
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
