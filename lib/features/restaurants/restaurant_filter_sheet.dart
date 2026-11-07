import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_popup.dart';
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

  Future<void> _dates() async {
    final result = await showDateRangePicker(
      context: context,
      helpText: '消费日期',
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialDateRange: query.start == null
          ? null
          : DateTimeRange(start: query.start!, end: query.end!),
    );
    if (result == null || !mounted) return;
    setState(() {
      query.start = result.start;
      query.end = result.end;
    });
  }

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

  Widget _region(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) {
    return MenuPopupButton<String>(
      tooltip: '选择$label',
      borderRadius: BorderRadius.circular(11),
      onSelected: onChanged,
      itemBuilder: (_) => [
        MenuPopupItem(
          value: '',
          icon: Icons.location_on_outlined,
          selected: value.isEmpty,
          child: const Text('全部'),
        ),
        for (final item in values)
          MenuPopupItem(
            value: item,
            icon: Icons.location_on_outlined,
            selected: value == item,
            child: Text(item),
          ),
      ],
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIconConstraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 24,
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
  }

  void _removeCompanion(String name) => setState(() {
    query.companions.remove(name);
    query.companionsOnly = query.companions.isNotEmpty;
  });

  @override
  Widget build(BuildContext context) {
    final restaurants = MenuScope.of(context).data.restaurants;
    final categories = restaurantCategoryNames(MenuScope.of(context).data);
    final addresses = restaurants.expand((r) => r.addressEntries).toList();
    List<String> unique(Iterable<String> values) =>
        values.where((value) => value.isNotEmpty).toSet().toList()..sort();
    final provinces = unique(addresses.map((a) => a.province));
    final cities = unique(
      addresses
          .where((a) => query.province.isEmpty || a.province == query.province)
          .map((a) => a.city),
    );
    final counties = unique(
      addresses
          .where(
            (a) =>
                (query.province.isEmpty || a.province == query.province) &&
                (query.city.isEmpty || a.city == query.city),
          )
          .map((a) => a.county),
    );
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
                    _heading('城市'),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked =
                            constraints.maxWidth < 280 ||
                            MediaQuery.textScalerOf(context).scale(13) > 22;
                        final controls = [
                          _region(
                            '省',
                            query.province,
                            provinces,
                            (value) => setState(() {
                              query.province = value;
                              query.city = '';
                              query.county = '';
                            }),
                          ),
                          _region(
                            '市',
                            query.city,
                            cities,
                            (value) => setState(() {
                              query.city = value;
                              query.county = '';
                            }),
                          ),
                          _region(
                            '区',
                            query.county,
                            counties,
                            (value) => setState(() => query.county = value),
                          ),
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
                    Semantics(
                      button: true,
                      label: query.start == null
                          ? '选择消费日期范围'
                          : '消费日期 ${_dateLabel(query.start!)} 至 ${_dateLabel(query.end!)}，点击修改范围',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _dates,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            suffixIcon: query.start == null
                                ? Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: MenuIcon(
                                      Icons.date_range_outlined,
                                      size: 18,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  )
                                : IconButton(
                                    tooltip: '清除日期',
                                    onPressed: () => setState(() {
                                      query.start = null;
                                      query.end = null;
                                    }),
                                    icon: const MenuIcon(Icons.close, size: 18),
                                  ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  query.start == null
                                      ? '开始日期'
                                      : _dateLabel(query.start!),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: query.start == null
                                        ? Theme.of(context).hintColor
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  '—',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  query.end == null
                                      ? '结束日期'
                                      : _dateLabel(query.end!),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: query.end == null
                                        ? Theme.of(context).hintColor
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _heading('菜系'),
                    const SizedBox(height: 6),
                    RestaurantCategoryInput(
                      controller: _category,
                      choices: categories,
                    ),
                    const SizedBox(height: 18),
                    _heading('饭搭子'),
                    const SizedBox(height: 6),
                    MenuSuggestionInput(
                      controller: _companion,
                      choices: people
                          .where((name) => !query.companions.contains(name))
                          .toList(),
                      hintText: '搜索并选择饭搭子',
                      showSuggestionsWhenEmpty: true,
                      emptyMessage: '没有找到这位饭搭子',
                      onSelected: (name) {
                        _companion.clear();
                        setState(() {
                          query.companions.add(name);
                          query.companionsOnly = true;
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
