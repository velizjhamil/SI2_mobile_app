import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import 'cuentas_service.dart';
import 'mock_auth_service.dart';

enum NotificationType { ingreso, egreso, info }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;
  final String? accountNumber;
  final String? amount;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.accountNumber,
    this.amount,
  });
}

class NotificationProvider extends ChangeNotifier {
  static const _storageKey = 'notifications_enabled_preference';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Polling de movimientos externos
  Timer? _pollingTimer;
  Map<int, double>? _lastBalances;
  final CuentasService _cuentasService = CuentasService();
  VoidCallback? onExternalMovementDetected;

  NotificationProvider() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final val = await _storage.read(key: _storageKey);
      if (val != null) {
        _notificationsEnabled = val == 'true';
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    try {
      await _storage.write(key: _storageKey, value: enabled.toString());
    } catch (_) {}
  }

  void addNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? accountNumber,
    String? amount,
    BuildContext? context,
  }) {
    final notification = AppNotification(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_notifications.length}',
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      accountNumber: accountNumber,
      amount: amount,
    );

    _notifications.insert(0, notification);
    notifyListeners();

    // Mostrar feedback visual emergente en pantalla si están habilitadas
    if (_notificationsEnabled && context != null && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                type == NotificationType.ingreso
                    ? Icons.arrow_downward_rounded
                    : (type == NotificationType.egreso
                        ? Icons.arrow_upward_rounded
                        : Icons.info_outline),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: type == NotificationType.ingreso
              ? const Color(0xFF1E6B3E)
              : (type == NotificationType.egreso
                  ? const Color(0xFFC0392B)
                  : const Color(0xFF2C3E50)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void notifyDeposit({
    required double monto,
    required String moneda,
    required String cuentaNumero,
    BuildContext? context,
  }) {
    addNotification(
      title: '¡Depósito Exitoso!',
      message: 'Se han depositado +$moneda ${monto.toStringAsFixed(2)} en tu cuenta $cuentaNumero',
      type: NotificationType.ingreso,
      accountNumber: cuentaNumero,
      amount: monto.toStringAsFixed(2),
      context: context,
    );
  }

  void notifyDiscount({
    required double monto,
    required String moneda,
    required String cuentaNumero,
    BuildContext? context,
  }) {
    addNotification(
      title: 'Descuento / Transferencia',
      message: 'Se han transferido -$moneda ${monto.toStringAsFixed(2)} de tu cuenta $cuentaNumero',
      type: NotificationType.egreso,
      accountNumber: cuentaNumero,
      amount: monto.toStringAsFixed(2),
      context: context,
    );
  }

  void notifyCreditPayment({
    required double monto,
    required String moneda,
    required String cuentaNumero,
    required int cuotaNumero,
    required String creditoNumero,
    BuildContext? context,
  }) {
    addNotification(
      title: 'Pago de Cuota Realizado',
      message: 'Se debitó -$moneda ${monto.toStringAsFixed(2)} de tu cuenta $cuentaNumero por cuota #$cuotaNumero del crédito $creditoNumero',
      type: NotificationType.egreso,
      accountNumber: cuentaNumero,
      amount: monto.toStringAsFixed(2),
      context: context,
    );
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  // Iniciar monitoreo periódico de cuentas para detectar movimientos externos
  void startMonitoring({BuildContext? context}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      await _checkMovements(context: context);
    });
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _checkMovements({BuildContext? context}) async {
    final token = AuthService.tokenJWT;
    if (token == null || token.isEmpty) return;

    final result = await _cuentasService.listarMisCuentas();
    if (context != null && !context.mounted) return;
    if (!result.success || result.cuentas.isEmpty) return;

    if (_lastBalances == null) {
      // Primer snapshot inicial
      _lastBalances = {
        for (var c in result.cuentas) c.id: c.availableBalance,
      };
      return;
    }

    bool changed = false;
    for (var c in result.cuentas) {
      final prev = _lastBalances![c.id];
      if (prev != null) {
        final diff = c.availableBalance - prev;
        if (diff > 0.009) {
          changed = true;
          if (context != null && !context.mounted) return;
          addNotification(
            title: '¡Depósito Recibido!',
            message:
                '+${c.currency.symbol} ${diff.toStringAsFixed(2)} en tu cuenta ${c.accountNumber}',
            type: NotificationType.ingreso,
            accountNumber: c.accountNumber,
            amount: diff.toStringAsFixed(2),
            context: context,
          );
        } else if (diff < -0.009) {
          changed = true;
          if (context != null && !context.mounted) return;
          addNotification(
            title: 'Movimiento / Descuento',
            message:
                '-${c.currency.symbol} ${(-diff).toStringAsFixed(2)} de tu cuenta ${c.accountNumber}',
            type: NotificationType.egreso,
            accountNumber: c.accountNumber,
            amount: (-diff).toStringAsFixed(2),
            context: context,
          );
        }
      }
      _lastBalances![c.id] = c.availableBalance;
    }

    if (changed) {
      onExternalMovementDetected?.call();
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

// Modal de la bandeja de notificaciones
void showNotificationTray(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _NotificationTraySheet(),
  );
}

class _NotificationTraySheet extends StatelessWidget {
  const _NotificationTraySheet();

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    NotificationProvider? provider;
    try {
      provider = Provider.of<NotificationProvider>(context);
    } catch (_) {}
    final notifications = provider?.notifications ?? [];
    final unreadCount = provider?.unreadCount ?? 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2420) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF101412);
    final subtextColor = isDark ? Colors.white60 : Colors.black54;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined,
                          color: AppColors.forestGreen, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Notificaciones',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.forestGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount nuevas',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (notifications.isNotEmpty)
                    TextButton(
                      onPressed: () => provider?.markAllAsRead(),
                      child: const Text('Leer todas'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none,
                              size: 48, color: subtextColor.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'No tienes notificaciones aún',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              color: subtextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aquí aparecerán tus depósitos y descuentos en tiempo real',
                            style: TextStyle(fontSize: 12, color: subtextColor),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        final isIngreso = n.type == NotificationType.ingreso;
                        final isEgreso = n.type == NotificationType.egreso;

                        return InkWell(
                          onTap: () => provider?.markAsRead(n.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: n.isRead
                                  ? (isDark
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : Colors.grey.shade50)
                                  : (isDark
                                      ? AppColors.forestGreen.withValues(alpha: 0.12)
                                      : AppColors.forestGreen.withValues(alpha: 0.08)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: n.isRead
                                    ? Colors.transparent
                                    : AppColors.forestGreen.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isIngreso
                                        ? const Color(0xFF1E6B3E).withValues(alpha: 0.15)
                                        : (isEgreso
                                            ? const Color(0xFFC0392B)
                                                .withValues(alpha: 0.15)
                                            : Colors.blue.withValues(alpha: 0.15)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isIngreso
                                        ? Icons.arrow_downward_rounded
                                        : (isEgreso
                                            ? Icons.arrow_upward_rounded
                                            : Icons.info_outline),
                                    color: isIngreso
                                        ? const Color(0xFF27AE60)
                                        : (isEgreso
                                            ? const Color(0xFFE74C3C)
                                            : Colors.blue),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            n.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: textColor,
                                            ),
                                          ),
                                          Text(
                                            _timeAgo(n.timestamp),
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: subtextColor),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.message,
                                        style: TextStyle(
                                            fontSize: 12, color: subtextColor),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!n.isRead) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: const BoxDecoration(
                                      color: AppColors.forestGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (notifications.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton.icon(
                  onPressed: () => provider?.clearAll(),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Limpiar historial de notificaciones'),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
