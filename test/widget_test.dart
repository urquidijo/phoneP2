// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:phone/src/app.dart';
import 'package:phone/src/state/cart_controller.dart';
import 'package:phone/src/state/session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Main navigation renders core tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionController();
    final cart = CartController();
    await session.bootstrap();
    await cart.load();

    await tester.pumpWidget(ElectroStoreApp(session: session, cart: cart));
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Carrito'), findsOneWidget);
    expect(find.text('Ofertas'), findsOneWidget);
  });
}
