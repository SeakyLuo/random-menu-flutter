import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/menu_icon.dart';
import 'restaurant_filter_pickers.dart';
import '../../ui/menu_tag.dart';
import '../../ui/menu_suggestion_input.dart';
import 'restaurant_filter.dart';
import 'restaurant_category_input.dart';
import 'restaurant_categories_page.dart';

class RestaurantFilterSheet extends StatefulWidget {
  const RestaurantFilterSheet({super.key, required this.query});
  final RestaurantQuery query;
  @override
  State<RestaurantFilterSheet> createState() => _RestaurantFilterSheetState();
}

class _RestaurantFilterSheetState extends State<RestaurantFilterSheet> {
  late RestaurantQuery query = widget.query.copy();
  late final _category = TextEditingController(text: widget.query.category);
  final _companion = TextEditingController();

  @override
  void dispose() {
    _category.dispose();
    _companion.dispose();
    super.dispose();
  }

  void _date(bool start) => showRestaurantDateWheel(
    context,
    start: start,
    startDate: query.start,
    endDate: query.end,
    onConfirm: (date) => setState(() {
      if (start) {
        query.start = date;
      } else {
        query.end = date;
      }
    }),
  );

  void _regions(int level) => showRestaurantRegionWheel(
    context,
    level: level,
    province: query.province,
    city: query.city,
    county: query.county,
    onConfirm: (province, city, county) => setState(() {
      query.province = province;
      query.city = city;
      query.county = county;
    }),
  );

  String _dateLabel(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  Widget _heading(String text, {Widget? action}) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 32),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        ?action,
      ],
    ),
  );

  Widget _region(String label, String value, int level) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _regions(level),
    child: InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 28,
          minHeight: 20,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: MenuIcon(
            Icons.expand_more,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      child: Text(
        value.isEmpty ? label : value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          color: value.isEmpty
              ? Theme.of(context).hintColor
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );

  Widget _dateField(bool start) {
    final date = start ? query.start : query.end;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _date(start),
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIconConstraints: const BoxConstraints(
            minWidth: 30,
            minHeight: 24,
          ),
          suffixIcon: date == null
              ? Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: MenuIcon(
                    Icons.date_range_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : IconButton(
                  tooltip: start ? '清除开始日期' : '清除结束日期',
                  onPressed: () => setState(() {
                    if (start) {
                      query.start = null;
                    } else {
                      query.end = null;
                    }
                  }),
                  icon: const MenuIcon(Icons.close, size: 18),
                ),
        ),
        child: Text(
          date == null ? (start ? '开始日期' : '结束日期') : _dateLabel(date),
          style: TextStyle(
            fontSize: 14,
            color: date == null
                ? Theme.of(context).hintColor
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  void _removeCompanion(String name) => setState(() {
    query.companions.remove(name);
    query.companionsOnly = query.companions.isNotEmpty;
  });

  @override
  Widget build(BuildContext context) {
    final restaurants = MenuScope.of(context).data.restaurants;
    final categories = restaurantCategoryNames(MenuScope.of(context).data);
    List<String> unique(Iterable<String> values) =>
        values.where((value) => value.isNotEmpty).toSet().toList()..sort();
    final people = unique(
      restaurants.expand((r) => r.records).expand((visit) => visit.companions),
    );
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '筛选餐厅',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const MenuIcon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _heading(
                      '城市',
                      action: query.hasRegion
                          ? TextButton(
                              onPressed: () => setState(() {
                                query.province = '';
                                query.city = '';
                                query.county = '';
                              }),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                '清除',
                                style: TextStyle(fontSize: 12),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked =
                            constraints.maxWidth < 280 ||
                            MediaQuery.textScalerOf(context).scale(13) > 22;
                        final controls = [
                          _region('省', query.province, 1),
                          _region('市', query.city, 2),
                          _region('区', query.county, 3),
                        ];
                        return stacked
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 8,
                                children: controls,
                              )
                            : Row(
                                spacing: 8,
                                children: [
                                  for (final control in controls)
                                    Expanded(child: control),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 18),
                    _heading('消费日期'),
                    const SizedBox(height: 6),
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(child: _dateField(true)),
                        Expanded(child: _dateField(false)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _heading('菜系'),
                    const SizedBox(height: 6),
                    RestaurantCategoryInput(
                      controller: _category,
                      choices: categories,
                      optionsViewOpenDirection: OptionsViewOpenDirection.up,
                    ),
                    const SizedBox(height: 18),
                    _heading('饭搭子'),
                    const SizedBox(height: 6),
                    MenuSuggestionInput(
                      controller: _companion,
                      optionsViewOpenDirection: OptionsViewOpenDirection.up,
                      choices: people
                          .where((name) => !query.companions.contains(name))
                          .toList(),
                      hintText: '搜索并选择饭搭子',
                      showSuggestionsWhenEmpty: true,
                      emptyMessage: '没有找到这位饭搭子',
                      onSelected: (name) {
                        setState(() {
                          query.companions.add(name);
                          query.companionsOnly = true;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _companion.clear();
                        });
                      },
                    ),
                    if (query.companions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final person in query.companions)
                            MenuTag(
                              person,
                              removable: true,
                              onRemove: () => _removeCompanion(person),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                spacing: 10,
                children: [
                  SizedBox.square(
                    dimension: 44,
                    child: IconButton(
                      tooltip: '重置筛选',
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        _category.clear();
                        _companion.clear();
                        setState(
                          () => query = RestaurantQuery(sort: query.sort),
                        );
                      },
                      icon: MenuIcon(
                        Icons.restart_alt,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        query.category = _category.text.trim();
                        Navigator.pop(context, query);
                      },
                      child: const Text('应用筛选'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
