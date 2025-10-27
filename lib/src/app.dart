import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_service.dart';
import 'core/navigation_scope.dart';
import 'core/notification_service.dart';
import 'core/push_service.dart';
import 'features/admin/admin_page.dart';
import 'features/auth/auth_page.dart';
import 'features/cart/cart_page.dart';
import 'features/discounts/discounts_page.dart';
import 'features/home/home_page.dart';
import 'features/invoices/invoices_page.dart';
import 'state/cart_controller.dart';
import 'state/session_controller.dart';
import 'widgets/push_banner.dart';

class ElectroStoreApp extends StatelessWidget {
  const ElectroStoreApp({
    super.key,
    required this.session,
    required this.cart,
  });

  final SessionController session;
  final CartController cart;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: cart),
      ],
      child: MaterialApp(
        title: 'ElectroStore movil',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        routes: {
          '/': (_) => const MainShell(),
          '/auth': (_) => const AuthPage(),
        },
        builder: (context, child) => PushMessageBanner(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  final ApiService _api = ApiService.instance;
  int _index = 0;
  bool _cartReminderShown = false;
  bool _discountReminderShown = false;
  SessionController? _session;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushService.instance.initialize();
    _evaluateReminders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.read<SessionController>();
    if (_session == session) return;
    _session?.removeListener(_handleSessionChange);
    _session = session;
    _wasAuthenticated = session.isAuthenticated;
    _session?.addListener(_handleSessionChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session?.removeListener(_handleSessionChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _evaluateReminders();
    }
  }

  void _handleSessionChange() {
    final session = _session;
    if (session == null) return;
    final isAuthenticated = session.isAuthenticated;
    if (isAuthenticated && !_wasAuthenticated) {
      _resetReminderFlags();
      _evaluateReminders();
    } else if (!isAuthenticated && _wasAuthenticated) {
      _resetReminderFlags();
    }
    _wasAuthenticated = isAuthenticated;
  }

  void _resetReminderFlags() {
    _cartReminderShown = false;
    _discountReminderShown = false;
  }

  Future<void> _evaluateReminders() async {
    final session = context.read<SessionController>();
    if (!session.isAuthenticated) return;
    final cart = context.read<CartController>();
    if (!_cartReminderShown && cart.items.isNotEmpty) {
      await NotificationService.instance.showCartReminder(cart.items.length);
      _cartReminderShown = true;
    }
    try {
      final discounts = await _api.fetchActiveDiscounts();
      if (!_discountReminderShown && discounts.isNotEmpty) {
        await NotificationService.instance.showDiscountReminder(discounts.length);
        _discountReminderShown = true;
      }
    } catch (_) {
      // Ignoramos errores de red para no interrumpir la experienca.
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final destinations = <_ShellDestination>[
      _ShellDestination(
        id: 'home',
        destination: const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
        child: const HomePage(),
      ),
      _ShellDestination(
        id: 'cart',
        destination:
            const NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Carrito'),
        child: const CartPage(),
      ),
      _ShellDestination(
        id: 'discounts',
        destination:
            const NavigationDestination(icon: Icon(Icons.percent_outlined), label: 'Ofertas'),
        child: const DiscountsPage(),
      ),
      _ShellDestination(
        id: 'invoices',
        destination: const NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Facturas'),
        child: const InvoicesPage(),
      ),
    ];

    if (session.user?.isAdmin ?? false) {
      destinations.add(
        _ShellDestination(
          id: 'admin',
          destination: const NavigationDestination(icon: Icon(Icons.shield), label: 'Admin'),
          child: const AdminPage(),
        ),
      );
    }

    final idIndex = {
      for (var i = 0; i < destinations.length; i++) destinations[i].id: i,
    };

    if (_index >= destinations.length) {
      _index = 0;
    }

    return ShellNavigationScope(
      idIndex: idIndex,
      onNavigate: (id) {
        final idx = idIndex[id];
        if (idx != null) {
          setState(() => _index = idx);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ElectroStore movil'),
          actions: [
            if (!session.isAuthenticated)
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/auth'),
                child: const Text('Iniciar sesion'),
              )
            else
              TextButton(
                onPressed: session.logout,
                child: const Text('Cerrar sesion'),
              ),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: destinations.map((entry) => entry.child).toList(),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          destinations: destinations.map((entry) => entry.destination).toList(),
          onDestinationSelected: (value) => setState(() => _index = value),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.id,
    required this.destination,
    required this.child,
  });

  final String id;
  final NavigationDestination destination;
  final Widget child;
}
