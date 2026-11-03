import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import 'cuentas_service.dart';
import 'mock_auth_service.dart';
import 'notificaciones_cooperativa_service.dart';
import 'session_manager.dart';
import 'system_notifications.dart';
import '../screens/socio_screens.dart';

enum NotificationType { ingreso, egreso, info, cooperativa }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;
  final String? accountNumber;
  final String? amount;

  /// Id en el backend de las notificaciones enviadas por la cooperativa
  /// (para marcarlas como leídas también en la web).
  final int? remoteId;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.accountNumber,
    this.amount,
    this.remoteId,
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

  // Notificaciones de la cooperativa (Gestionar notificaciones en la web).
  final NotificacionesCooperativaService _cooperativaService;
  final Set<int> _remoteIdsVistos = {};
  String? _cooperativaUserId;
  bool _cooperativaSincronizada = false;

  NotificationProvider({NotificacionesCooperativaService? cooperativaService})
      : _cooperativaService = cooperativaService ?? NotificacionesCooperativaService() {
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
    int? remoteId,
    DateTime? timestamp,
    bool isRead = false,
    bool alertar = true,
  }) {
    final notification = AppNotification(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_notifications.length}',
      title: title,
      message: message,
      type: type,
      timestamp: timestamp ?? DateTime.now(),
      isRead: isRead,
      accountNumber: accountNumber,
      amount: amount,
      remoteId: remoteId,
    );

    _notifications.insert(0, notification);
    notifyListeners();

    // Notificación del sistema: suena, vibra y queda en la barra de Android.
    if (_notificationsEnabled && alertar) {
      SystemNotifications.instance.show(title: title, body: message);
    }

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
      final remoteId = _notifications[index].remoteId;
      if (remoteId != null) _cooperativaService.marcarLeida(remoteId);
    }
  }

  void markAllAsRead() {
    final hayRemotasSinLeer = _notifications.any((n) => !n.isRead && n.remoteId != null);
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
    if (hayRemotasSinLeer) _cooperativaService.marcarTodas();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  void addRemoteNotification({
    required String id,
    required String title,
    required String message,
    int? creditId,
  }) {
    if (_notifications.any((n) => n.id == id)) return;
    _notifications.insert(
      0,
      AppNotification(
        id: id.isNotEmpty
            ? id
            : '_',
        title: title,
        message: message,
        type: NotificationType.info,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void openCreditSchedule(int creditId) {
    final navContext = appNavigatorKey.currentContext;
    if (navContext != null) {
      Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (_) => CronogramaCreditoScreen(creditId: creditId),
        ),
      );
    }
  }

  // Iniciar monitoreo periódico de cuentas para detectar movimientos externos
  void startMonitoring({BuildContext? context}) {
    // Pide el permiso de notificaciones y abre la bandeja al tocar un aviso.
    SystemNotifications.instance.onTap = () {
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null) showNotificationTray(ctx);
    };
    SystemNotifications.instance.init();
    checkCooperativa();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      await _checkMovements(context: context);
      await checkCooperativa();
    });
  }

  /// Trae las notificaciones enviadas por la cooperativa. La primera
  /// sincronización solo carga la bandeja; las que llegan después suenan.
  Future<void> checkCooperativa() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;
    if (userId != _cooperativaUserId) {
      // Otro usuario inició sesión: no mezclar su bandeja con la anterior.
      _cooperativaUserId = userId;
      _cooperativaSincronizada = false;
      _remoteIdsVistos.clear();
      _notifications.removeWhere((n) => n.remoteId != null);
    }

    final items = await _cooperativaService.listar();
    if (items == null || userId != _cooperativaUserId) return;

    final primeraVez = !_cooperativaSincronizada;
    // El backend las devuelve de la más nueva a la más antigua; se insertan al
    // inicio, así que se recorren al revés para conservar el orden.
    for (final item in items.reversed) {
      if (!_remoteIdsVistos.add(item.id)) continue;
      addNotification(
        title: item.titulo,
        message: item.mensaje,
        type: NotificationType.cooperativa,
        remoteId: item.id,
        timestamp: item.fecha,
        isRead: item.leida,
        alertar: !primeraVez && !item.leida,
      );
    }
    _cooperativaSincronizada = true;
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
                            'Aquí aparecerán tus movimientos y los avisos de tu cooperativa',
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
                        final isCooperativa = n.type == NotificationType.cooperativa;

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
                                            : isCooperativa
                                                ? Colors.amber.withValues(alpha: 0.18)
                                                : Colors.blue.withValues(alpha: 0.15)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isIngreso
                                        ? Icons.arrow_downward_rounded
                                        : (isEgreso
                                            ? Icons.arrow_upward_rounded
                                            : isCooperativa
                                                ? Icons.campaign_outlined
                                                : Icons.info_outline),
                                    color: isIngreso
                                        ? const Color(0xFF27AE60)
                                        : (isEgreso
                                            ? const Color(0xFFE74C3C)
                                            : isCooperativa
                                                ? Colors.amber.shade800
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
