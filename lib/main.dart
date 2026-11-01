import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/menu_store.dart';
import 'features/personal/personal_page.dart';
import 'features/random/random_page.dart';
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

class RandomMenuApp extends StatelessWidget {
  const RandomMenuApp({super.key, required this.store});
  final MenuStore store;
  @override
  Widget build(BuildContext context) => MenuScope(
    store: store,
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        title: '随机菜单',
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: menuTheme(Brightness.light),
        darkTheme: menuTheme(Brightness.dark),
        themeMode: switch (store.data.themeMode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        home: const MenuHome(),
      ),
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
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: .16),
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
          child: IndexedStack(
            index: _selected,
            children: [
              RandomPage(onOpenRecipes: () => setState(() => _selected = 1)),
              const RecipesPage(),
              const RestaurantsPage(),
              const PersonalPage(),
            ],
          ),
        ),
        bottomNavigationBar: MenuBottomBar(
          selected: _selected,
          onSelected: (index) => setState(() => _selected = index),
        ),
      ),
    ),
  );
}
