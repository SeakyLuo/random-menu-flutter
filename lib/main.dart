import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/menu_store.dart';
import 'features/mcp/menu_mcp_server.dart';
import 'features/personal/personal_page.dart';
import 'features/random/random_page.dart';
import 'features/random/random_theme.dart';
import 'features/recipes/recipes_page.dart';
import 'features/restaurants/restaurants_page.dart';
import 'ui/bottom_bar.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final store = await MenuStore.open();
  await MenuMcpServer.open(store);
  runApp(RandomMenuApp(store: store));
}

class RandomMenuApp extends StatefulWidget {
  const RandomMenuApp({super.key, required this.store});
  final MenuStore store;
  @override
  State<RandomMenuApp> createState() => _RandomMenuAppState();
}

class _RandomMenuAppState extends State<RandomMenuApp> {
  late String _appearance = widget.store.data.themeMode;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_appearanceChanged);
    _lifecycle = AppLifecycleListener(onResume: widget.store.reload);
  }

  void _appearanceChanged() {
    final appearance = widget.store.data.themeMode;
    if (appearance == _appearance) return;
    setState(() => _appearance = appearance);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.store.removeListener(_appearanceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MenuScope(
    store: widget.store,
    child: MaterialApp(
      title: '随机菜单',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: menuTheme(Brightness.light),
      darkTheme: menuTheme(Brightness.dark),
      themeMode: switch (_appearance) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: const MenuHome(),
    ),
  );
}

class MenuHome extends StatefulWidget {
  const MenuHome({super.key});
  @override
  State<MenuHome> createState() => _MenuHomeState();
}

class _MenuHomeState extends State<MenuHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final error = MenuMcpServer.instance.startupError;
      if (error != null && mounted) showToast(context, error);
    });
  }

  int _selected = 0;
  bool _picking = false;
  final _pages = PageController();
  final _recipesKey = GlobalKey<RecipesPageState>();
  final _restaurantsKey = GlobalKey<RestaurantsPageState>();

  void _selectTab(int index) {
    if (_picking) return;
    if (index == _selected) {
      if (_pages.position.isScrollingNotifier.value) return;
      switch (index) {
        case 1:
          _recipesKey.currentState!.scrollToTop();
        case 2:
          _restaurantsKey.currentState!.scrollToTop();
      }
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _selected = index);
      if (MediaQuery.disableAnimationsOf(context)) {
        _pages.jumpToPage(index);
      } else {
        _pages.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: menuSystemUiStyle(Theme.of(context).brightness),
    child: PopScope(
      canPop: _selected == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _selectTab(0);
      },
      child: Scaffold(
        extendBody: true,
        body: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: PageView(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              Theme(
                data: randomHomeTheme(Theme.of(context)),
                child: RandomPage(
                  onOpenRecipes: () => _selectTab(1),
                  onBusy: (busy) => setState(() => _picking = busy),
                ),
              ),
              RecipesPage(key: _recipesKey),
              RestaurantsPage(key: _restaurantsKey),
              PersonalPage(onNavigate: _selectTab),
            ].map((page) => _HomeTabPage(child: page)).toList(),
          ),
        ),
        bottomNavigationBar: MenuBottomBar(
          selected: _selected,
          pages: _pages,
          onSelected: _selectTab,
        ),
      ),
    ),
  );
}

class _HomeTabPage extends StatefulWidget {
  const _HomeTabPage({required this.child});
  final Widget child;

  @override
  State<_HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<_HomeTabPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
