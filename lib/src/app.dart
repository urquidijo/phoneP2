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
  const ElectroStoreApp({super.key, required this.session, required this.cart});

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
        title: 'ElectroStore móvil',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: false),
        ),
        routes: {
          '/': (_) => const MainShell(),
          '/auth': (_) => const AuthPage(),
        },
        builder: (context, child) =>
            PushMessageBanner(child: child ?? const SizedBox.shrink()),
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
    setState(() {}); // refresca avatar/menu
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
        await NotificationService.instance.showDiscountReminder(
          discounts.length,
        );
        _discountReminderShown = true;
      }
    } catch (_) {
      // Ignoramos errores de red
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final cart = context.watch<CartController>();
    final cartCount = cart.items.length;

    final destinations = _buildDestinations(
      context,
      cartCount,
      isAdmin: session.user?.isAdmin ?? false,
    );

    final idIndex = {
      for (var i = 0; i < destinations.length; i++) destinations[i].id: i,
    };

    if (_index >= destinations.length) _index = 0;

    // Debug: estado de sesión
    debugPrint(
      'isAuth=${session.isAuthenticated} user=${session.user?.username ?? "null"}',
    );

    return ShellNavigationScope(
      idIndex: idIndex,
      onNavigate: (id) {
        final idx = idIndex[id];
        if (idx != null) setState(() => _index = idx);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;

          return Scaffold(
            appBar: AppBar(
              titleSpacing: 16,
              // Título que no tapa las actions
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.electric_bolt_rounded, size: 22),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'ElectroStore',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                // Botón visible si no hay sesión o user
                if (!(session.isAuthenticated) || session.user == null)
                  IconButton(
                    tooltip: 'Iniciar sesión',
                    onPressed: () => Navigator.of(context).pushNamed('/auth'),
                    icon: const Icon(Icons.login_rounded),
                  )
                else
                  _AccountMenu(
                    username: session.user?.username ?? 'Usuario',
                    onLogout: session.logout,
                  ),
                const SizedBox(width: 4),
              ],
            ),
            body: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: IndexedStack(
                  key: ValueKey(destinations.length),
                  index: _index,
                  children: destinations.map((e) => e.child).toList(),
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: NavigationBar(
                selectedIndex: _index,
                labelBehavior: isNarrow
                    ? NavigationDestinationLabelBehavior.alwaysHide
                    : NavigationDestinationLabelBehavior.alwaysShow,
                destinations: destinations.map((e) => e.destination).toList(),
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
              ),
            ),
            // 🧹 FAB del carrito eliminado como pediste
          );
        },
      ),
    );
  }

  List<_ShellDestination> _buildDestinations(
    BuildContext context,
    int cartCount, {
    required bool isAdmin,
  }) {
    final badgeColor = Theme.of(context).colorScheme.error;
    final cartIcon = cartCount > 0
        ? Badge.count(
            count: cartCount,
            backgroundColor: badgeColor,
            textColor: Theme.of(context).colorScheme.onError,
            smallSize: 18,
            child: const Icon(Icons.shopping_cart_outlined),
          )
        : const Icon(Icons.shopping_cart_outlined);

    final base = <_ShellDestination>[
      _ShellDestination(
        id: 'home',
        destination: const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        child: const HomePage(),
      ),
      _ShellDestination(
        id: 'cart',
        destination: NavigationDestination(
          icon: cartIcon,
          selectedIcon: cartIcon,
          label: 'Carrito',
        ),
        child: const CartPage(),
      ),
      _ShellDestination(
        id: 'discounts',
        destination: const NavigationDestination(
          icon: Icon(Icons.percent_outlined),
          selectedIcon: Icon(Icons.percent),
          label: 'Ofertas',
        ),
        child: const DiscountsPage(),
      ),
      _ShellDestination(
        id: 'invoices',
        destination: const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Facturas',
        ),
        child: const InvoicesPage(),
      ),
    ];

    if (isAdmin) {
      base.add(
        _ShellDestination(
          id: 'admin',
          destination: const NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Admin',
          ),
          child: const AdminPage(),
        ),
      );
    }
    return base;
  }

  // static String _capCount(int n) => n > 99 ? '99+' : (n > 9 ? '9+' : '$n');
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

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.username, required this.onLogout});

  final String username;
  final VoidCallback onLogout;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: 14,
      child: Text(
        _initials(username),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Cuenta',
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded),
            title: Text('Cerrar sesión'),
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'logout') onLogout();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: avatar,
      ),
    );
  }
}
