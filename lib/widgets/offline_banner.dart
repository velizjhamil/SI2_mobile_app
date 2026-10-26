import 'package:flutter/material.dart';

String formatCachedDate(DateTime dt) {
  final d = dt.toLocal();
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  final year = d.year.toString();
  final hour = d.hour.toString().padLeft(2, '0');
  final minute = d.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

class OfflineBanner extends StatelessWidget {
  final DateTime? cachedTimestamp;
  final String? customMessage;

  const OfflineBanner({
    super.key,
    this.cachedTimestamp,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final text = customMessage ??
        (cachedTimestamp != null
            ? 'Sin conexión — datos guardados el ${formatCachedDate(cachedTimestamp!)}'
            : 'Sin conexión');

    return Container(
      key: const Key('offline_banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.amber.shade800,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
