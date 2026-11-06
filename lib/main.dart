import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/menu_store.dart';
import 'features/personal/personal_page.dart';
import 'features/random/random_page.dart';
import 'features/random/random_theme.dart';
import 'features/recipes/recipes_page.dart';
import 'features/restaurants/restaurants_page.dart';
import 'ui/bottom_bar.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final store = await MenuStore.open();
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

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_appearanceChanged);
  }

  void _appearanceChanged() {
    final appearance = widget.store.data.themeMode;
    if (appearance == _appearance) return;
    setState(() => _appearance = appearance);
  }

  @override
  void dispose() {
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
  int _selected = 0;
  bool _picking = false;
  final _recipesKey = GlobalKey<RecipesPageState>();
  final _restaurantsKey = GlobalKey<RestaurantsPageState>();

  void _selectTab(int index) {
    if (_picking) return;
    if (index == _selected) {
      switch (index) {
        case 1:
          _recipesKey.currentState!.scrollToTop();
        case 2:
          _restaurantsKey.currentState!.scrollToTop();
      }
    } else {
      setState(() => _selected = index);
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: menuSystemUiStyle(Theme.of(context).brightness),
    child: PopScope(
      canPop: _selected == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _selected = 0);
      },
      child: Scaffold(
        extendBody: true,
        body: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: IndexedStack(
            index: _selected,
            children: [
              Theme(
                data: randomHomeTheme(Theme.of(context)),
                child: RandomPage(
                  onOpenRecipes: () => setState(() => _selected = 1),
                  onBusy: (busy) => setState(() => _picking = busy),
                ),
              ),
              RecipesPage(key: _recipesKey),
              RestaurantsPage(key: _restaurantsKey),
              PersonalPage(
                onNavigate: (index) => setState(() => _selected = index),
              ),
            ],
          ),
        ),
        bottomNavigationBar: MenuBottomBar(
          selected: _selected,
          onSelected: _selectTab,
        ),
      ),
    ),
  );
}
