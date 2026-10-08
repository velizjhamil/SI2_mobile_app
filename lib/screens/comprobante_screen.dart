import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/comprobante_model.dart';
import '../services/comprobantes_service.dart';

class ComprobanteScreen extends StatefulWidget {
  final Comprobante comprobante;
  final ComprobantesService? service;

  const ComprobanteScreen({
    super.key,
    required this.comprobante,
    this.service,
  });

  @override
  State<ComprobanteScreen> createState() => _ComprobanteScreenState();
}

class _ComprobanteScreenState extends State<ComprobanteScreen> {
  bool _sharing = false;

  String _dateTime() {
    final value = widget.comprobante.issuedAt?.toLocal();
    if (value == null) return 'Fecha no disponible';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.day}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Future<void> _sharePdf() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final result =
        await (widget.service ?? ComprobantesService()).pdf(widget.comprobante.id);
    if (!mounted) return;
    if (!result.success || result.value == null) {
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'No se pudo descargar el PDF.')),
      );
      return;
    }
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${widget.comprobante.number}.pdf');
      await file.writeAsBytes(result.value!, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Comprobante ${widget.comprobante.number}',
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo compartir el comprobante.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.comprobante;
    return Scaffold(
      appBar: AppBar(title: const Text('Comprobante')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.verified, color: Colors.green, size: 48),
          const SizedBox(height: 8),
          Text(receipt.number,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _line('Tipo', receipt.type == 'PAGO_CUOTA' ? 'Pago de cuota' : 'Transferencia'),
          _line('Fecha y hora', _dateTime()),
          _line('Monto', '${receipt.amount} ${receipt.currency}'),
          _line('Cuenta origen', receipt.sourceAccount),
          if (receipt.destinationAccount != null)
            _line('Cuenta destino', receipt.destinationAccount!),
          if (receipt.creditId != null) _line('Crédito', '${receipt.creditId}'),
          if (receipt.installmentNumber != null)
            _line('Número de cuota', '${receipt.installmentNumber}'),
          if (receipt.description != null && receipt.description!.isNotEmpty)
            _line('Glosa', receipt.description!),
          _line('Código de verificación', receipt.verificationCode),
          const SizedBox(height: 16),
          Center(
            child: QrImageView(
              data: receipt.verificationUrl,
              size: 190,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('share-pdf'),
            onPressed: _sharing ? null : _sharePdf,
            icon: const Icon(Icons.share),
            label: Text(_sharing ? 'Preparando PDF...' : 'Compartir PDF'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            key: const Key('receipt-done'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(label)),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
