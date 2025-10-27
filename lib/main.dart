import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';
import 'src/core/notification_service.dart';
import 'src/state/cart_controller.dart';
import 'src/state/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX', null);
  await NotificationService.instance.initialize();
  final session = SessionController();
  final cart = CartController();
  await Future.wait([
    session.bootstrap(),
    cart.load(),
  ]);
  runApp(ElectroStoreApp(session: session, cart: cart));
}
