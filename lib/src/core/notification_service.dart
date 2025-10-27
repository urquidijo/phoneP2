import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final AndroidNotificationChannel _defaultChannel = const AndroidNotificationChannel(
    'reminders_channel',
    'Recordatorios',
    description: 'Avisos sobre carritos pendientes y descuentos',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(initializationSettings);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_defaultChannel);
  }

  Future<void> showNotification({
    required String id,
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _defaultChannel.id,
      _defaultChannel.name,
      channelDescription: _defaultChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: const DefaultStyleInformation(true, true),
    );
    await _plugin.show(
      id.hashCode & 0x7fffffff,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showCartReminder(int itemsCount) async {
    final body = itemsCount == 1
        ? 'Tienes 1 producto esperando en tu carrito. Completa tu compra ahora.'
        : 'Tienes $itemsCount productos esperando en tu carrito. No te quedes sin ellos.';
    await showNotification(
      id: 'cart_reminder',
      title: 'Carrito pendiente',
      body: body,
    );
  }

  Future<void> showDiscountReminder(int discountsCount) async {
    final body = discountsCount == 1
        ? 'Hay un producto con descuento disponible para ti.'
        : 'Hay $discountsCount productos con descuento esperándote.';
    await showNotification(
      id: 'discount_alert',
      title: 'Nuevos descuentos activos',
      body: body,
    );
  }
}
