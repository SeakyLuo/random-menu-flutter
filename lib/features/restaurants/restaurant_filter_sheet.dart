import '../../ui/menu_field_label.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_numeric_fields.dart';
import '../../ui/widgets.dart';
import 'restaurant_filter_pickers.dart';
import '../../ui/menu_tag.dart';
import '../../ui/menu_suggestion_input.dart';
import 'restaurant_filter.dart';
import '../../ui/tag_selection_field.dart';
import 'restaurant_categories_page.dart';

class RestaurantFilterSheet extends StatefulWidget {
  const RestaurantFilterSheet({super.key, required this.query});
  final RestaurantQuery query;
  @override
  State<RestaurantFilterSheet> createState() => _RestaurantFilterSheetState();
}

class _RestaurantFilterSheetState extends State<RestaurantFilterSheet> {
  late RestaurantQuery query = widget.query.copy();
  late final _companion = TextEditingController(
    text: query.alone ? '独自用餐' : query.companion,
  );
  late final _address = TextEditingController(text: query.address);
  late final _minPrice = TextEditingController(
    text: query.minPrice == null ? '' : money(query.minPrice!),
  );
  late final _maxPrice = TextEditingController(
    text: query.maxPrice == null ? '' : money(query.maxPrice!),
  );

  @override
  void dispose() {
    _companion.dispose();
    _address.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
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
      query.withoutRegion = null;
      query.address = '';
      _address.clear();
    }),
  );

  String _dateLabel(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Widget _heading(String text, IconData icon, {Widget? action}) =>
      MenuFieldLabel(
        text,
        icon: icon,
        minHeight: 32,
        bottomSpacing: 0,
        trailing: action,
      );

  Widget _region(String label, String value, int level) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _regions(level),
    child: InputDecorator(
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              ? null
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

  @override
  Widget build(BuildContext context) {
    final restaurants = MenuScope.of(context).data.restaurants;
    final categories = restaurantCategoryNames(MenuScope.of(context).data);
    List<String> unique(Iterable<String> values) =>
        values.where((value) => value.isNotEmpty).toSet().toList()..sort();
    final people = [
      '独自用餐',
      ...unique(
        restaurants
            .expand((r) => r.records)
            .expand((visit) => visit.companions),
      ),
    ];
    final addresses = unique(
      restaurants
          .expand((r) => r.addressEntries)
          .where(
            (address) =>
                (query.province.isEmpty ||
                    address.province == query.province) &&
                (query.city.isEmpty || address.city == query.city) &&
                (query.county.isEmpty || address.county == query.county),
          )
          .map((address) => address.detail),
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
                      Icons.place_outlined,
                      action: query.hasLocation
                          ? TextButton(
                              onPressed: () => setState(() {
                                query.province = '';
                                query.city = '';
                                query.county = '';
                                query.address = '';
                                query.withoutRegion = null;
                                _address.clear();
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
                          _region('区县', query.county, 3),
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
                    if (query.withoutRegion != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: MenuTag(
                          switch (query.withoutRegion!) {
                            RestaurantRegionLevel.province => '未填写省份',
                            RestaurantRegionLevel.city => '未填写城市',
                            RestaurantRegionLevel.county => '未填写区县',
                          },
                          removable: true,
                          onRemove: () =>
                              setState(() => query.withoutRegion = null),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _heading('地址', Icons.storefront_outlined),
                    const SizedBox(height: 6),
                    MenuSuggestionInput(
                      controller: _address,
                      choices: addresses,
                      hintText: '输入或选择地址，完全匹配',
                      showSuggestionsWhenEmpty: true,
                      adaptToAvailableSpace: true,
                    ),
                    const SizedBox(height: 18),
                    _heading('消费日期', Icons.date_range_outlined),
                    const SizedBox(height: 6),
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(child: _dateField(true)),
                        Expanded(child: _dateField(false)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TagSelectionField(
                      label: '菜系',
                      icon: Icons.restaurant_outlined,
                      selected: query.categories,
                      hierarchical: true,
                      choices: categories,
                      allowCreate: false,
                      onChanged: (value) => setState(() {
                        query.categories = value;
                        query.exactCategories = false;
                        if (value.isNotEmpty) query.uncategorized = false;
                      }),
                    ),
                    if (query.categories.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '同时满足所选菜系',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (query.uncategorized) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: MenuTag(
                          '未分类',
                          removable: true,
                          onRemove: () =>
                              setState(() => query.uncategorized = false),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _heading('人均价格', Icons.receipt_long_outlined),
                    const SizedBox(height: 6),
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: MenuPriceField(
                            controller: _minPrice,
                            currency: query.currency,
                            onCurrencyChanged: (currency) =>
                                setState(() => query.currency = currency),
                            hintText: '最低价',
                          ),
                        ),
                        Text(
                          '—',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        Expanded(
                          child: MenuPriceField(
                            controller: _maxPrice,
                            currency: query.currency,
                            onCurrencyChanged: (currency) =>
                                setState(() => query.currency = currency),
                            hintText: '最高价',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _heading('饭搭子', Icons.people_outline),
                    const SizedBox(height: 6),
                    MenuSuggestionInput(
                      controller: _companion,
                      optionsViewOpenDirection: OptionsViewOpenDirection.up,
                      choices: people,
                      hintText: '搜索并选择饭搭子',
                      showSuggestionsWhenEmpty: true,
                      emptyMessage: '没有找到这位饭搭子',
                      onSelected: (name) {
                        setState(() {
                          query.alone = name == '独自用餐';
                          query.companion = query.alone ? '' : name;
                        });
                      },
                    ),
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
                        Navigator.pop(
                          context,
                          RestaurantQuery(sort: query.sort),
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
                        final minText = _minPrice.text.trim();
                        final maxText = _maxPrice.text.trim();
                        final min = double.tryParse(minText);
                        final max = double.tryParse(maxText);
                        if ((minText.isNotEmpty &&
                                (min == null || !min.isFinite || min < 0)) ||
                            (maxText.isNotEmpty &&
                                (max == null || !max.isFinite || max < 0))) {
                          showToast(context, '请输入有效的人均价格');
                          return;
                        }
                        if (min != null && max != null && min > max) {
                          showToast(context, '最低价不能高于最高价');
                          return;
                        }
                        FocusScope.of(context).unfocus();
                        query.minPrice = min;
                        query.maxPrice = max;
                        query.uncategorized =
                            query.uncategorized && query.categories.isEmpty;
                        query.address = _address.text.trim();
                        query.alone = _companion.text.trim() == '独自用餐';
                        query.companion = query.alone
                            ? ''
                            : _companion.text.trim();
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
