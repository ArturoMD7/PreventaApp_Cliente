import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  RealtimeChannel? _channel;
  List<String> _clienteIds = [];

  Future<void> init() async {
    if (kIsWeb) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    const androidChannel = AndroidNotificationChannel(
      'pedidos_estado',
      'Estado de Pedidos',
      description: 'Notificaciones cuando el proveedor actualiza tus pedidos',
      importance: Importance.high,
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);

    await _startRealtimeSubscription();
  }

  Future<void> _startRealtimeSubscription() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final clienteRows = await _supabase
        .from('clientes')
        .select('id')
        .eq('telefono', userId);

    final rows = clienteRows as List;
    if (rows.isEmpty) return;

    _clienteIds = rows.map((r) => r['id'] as String).toList();

    _channel?.unsubscribe();

    _channel = _supabase
        .channel('ventas-cliente-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ventas',
          filter: PostgresChangeFilter(
            column: 'cliente_id',
            type: PostgresChangeFilterType.inFilter,
            value: _clienteIds,
          ),
          callback: _handleUpdate,
        )
        .subscribe();
  }

  Future<void> _handleUpdate(PostgresChangePayload payload) async {
    final oldRecord = payload.oldRecord;
    final newRecord = payload.newRecord;

    final String oldEstado = oldRecord['estado'] ?? '';
    final String newEstado = newRecord['estado'] ?? '';

    if (oldEstado == newEstado) return;

    final String providerId = newRecord['user_id'] ?? '';

    String negocioNombre = 'Tu proveedor';
    if (providerId.isNotEmpty) {
      try {
        final res = await _supabase
            .from('negocios')
            .select('nombre_negocio')
            .eq('id', providerId)
            .maybeSingle();
        if (res != null) {
          negocioNombre = res['nombre_negocio'] ?? 'Tu proveedor';
        }
      } catch (_) {}
    }

    String mensaje;
    switch (newEstado) {
      case 'entregado':
        mensaje = '$negocioNombre marcó tu pedido como entregado';
        break;
      case 'en_proceso':
        mensaje = '$negocioNombre puso tu pedido en proceso';
        break;
      case 'cancelado':
        mensaje = '$negocioNombre canceló tu pedido';
        break;
      case 'descartado':
        mensaje = '$negocioNombre descartó tu pedido';
        break;
      default:
        mensaje = '$negocioNombre cambió el estado a "$newEstado"';
    }

    _showNotification(
      title: 'Pedido Actualizado',
      body: mensaje,
    );
  }

  void _showNotification({
    required String title,
    required String body,
  }) {
    final notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);
    _localNotifications.show(
      notificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pedidos_estado',
          'Estado de Pedidos',
          channelDescription: 'Actualizaciones de estado de tus pedidos',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> refreshSubscription() async {
    await _startRealtimeSubscription();
  }

  void dispose() {
    _channel?.unsubscribe();
  }
}
