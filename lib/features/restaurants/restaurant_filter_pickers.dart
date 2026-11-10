import 'package:flutter/cupertino.dart'
    show CupertinoPickerDefaultSelectionOverlay;
import 'package:flutter/material.dart';
import 'package:flutter_pickers/address_picker/locations_data.dart';
import 'package:flutter_pickers/pickers.dart';
import 'package:flutter_pickers/style/picker_style.dart';
import 'package:flutter_pickers/time_picker/model/date_mode.dart';
import 'package:flutter_pickers/time_picker/model/pduration.dart';

PickerStyle _style(BuildContext context, String title) {
  final scheme = Theme.of(context).colorScheme;
  Widget button(String label, Color color) => SizedBox(
    width: 64,
    height: 48,
    child: Center(
      child: Text(label, style: TextStyle(fontSize: 15, color: color)),
    ),
  );
  return PickerStyle(
    context: context,
    backgroundColor: scheme.surface,
    headDecoration: BoxDecoration(color: scheme.surface),
    pickerTitleHeight: 48,
    pickerHeight: 240,
    pickerItemHeight: 40,
    textSize: 16,
    textColor: scheme.onSurface,
    itemOverlay: const CupertinoPickerDefaultSelectionOverlay(),
    title: Center(
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    ),
    cancelButton: button('取消', scheme.onSurfaceVariant),
    commitButton: button('确定', scheme.primary),
  );
}

const _municipalities = {'北京市', '天津市', '上海市', '重庆市'};

void showRestaurantRegionWheel(
  BuildContext context, {
  required int level,
  required String province,
  required String city,
  required String county,
  required void Function(String province, String city, String county) onConfirm,
}) {
  FocusScope.of(context).unfocus();
  final depth = county.isNotEmpty
      ? 3
      : city.isNotEmpty && level < 2
      ? 2
      : level;
  if (depth == 1) {
    Pickers.showSinglePicker(
      context,
      data: Address.provinces,
      selectData: province,
      pickerStyle: _style(context, '选择省份'),
      onConfirm: (value, _) => onConfirm(value as String, '', ''),
    );
    return;
  }
  // The existing address model stores a municipality's name at both levels.
  // The package's administrative data labels its city level “市辖区”.
  final pickerCity = city == province && _municipalities.contains(province)
      ? '市辖区'
      : city;
  Pickers.showAddressPicker(
    context,
    initProvince: province,
    initCity: pickerCity,
    initTown: depth == 3 ? county : null,
    addAllItem: false,
    pickerStyle: _style(context, depth == 3 ? '选择省市区县' : '选择城市'),
    onConfirm: (selectedProvince, selectedCity, selectedCounty) {
      final municipality = _municipalities.contains(selectedProvince);
      onConfirm(
        selectedProvince,
        municipality ? selectedProvince : selectedCity,
        depth == 3 ? selectedCounty! : '',
      );
    },
  );
}

void showRestaurantDateWheel(
  BuildContext context, {
  required bool start,
  required DateTime? startDate,
  required DateTime? endDate,
  required ValueChanged<DateTime> onConfirm,
}) {
  FocusScope.of(context).unfocus();
  final initial = start
      ? startDate ?? endDate ?? DateTime.now()
      : endDate ?? startDate ?? DateTime.now();
  Pickers.showDatePicker(
    context,
    mode: DateMode.YMD,
    selectDate: PDuration.parse(initial),
    minDate: PDuration.parse(
      !start && startDate != null ? startDate : DateTime(1900),
    ),
    maxDate: PDuration.parse(
      start && endDate != null ? endDate : DateTime(2100, 12, 31),
    ),
    pickerStyle: _style(context, start ? '开始日期' : '结束日期'),
    onConfirm: (date) =>
        onConfirm(DateTime(date.year!, date.month!, date.day!)),
  );
}
