const restaurantCategoryTagChanges = <String, List<String>>{
  '重庆火锅': ['火锅/重庆火锅'],
  '日本菜': ['日本料理'],
  '日本烤肉': ['烤肉/日本烤肉'],
  '韩国烤肉': ['烤肉/韩国烤肉'],
  '泰国火锅': ['火锅/泰式火锅'],
  '烤串': ['烧烤'],
  '其他': [],
  '不明': [],
};

List<String> upgradedRestaurantTags(String name, List<String> categories) {
  final tags = <String>{
    for (final category in categories)
      ...restaurantCategoryTagChanges[category] ?? [category],
  };
  if (name.contains('韩国烤肉') ||
      const {
        '花肉匠',
        '韩宫宴烤肉',
        '姜虎东烤肉',
        '王妃家炭火烤肉',
        '韩时烤肉',
        '偶巴明洞烤肉',
        '山茶花韩国锅盖烤肉',
      }.contains(name)) {
    tags.remove('烤肉');
    tags.add('烤肉/韩国烤肉');
  }
  if (name == '集渔泰式海鲜火锅') tags.add('火锅/泰式火锅');
  if (name == '艳·台湾火锅') {
    tags
      ..remove('火锅')
      ..add('火锅/台式火锅');
  }
  if (const {'左庭右院', '潮品牛肉'}.contains(name)) {
    tags
      ..remove('火锅')
      ..add('火锅/潮汕牛肉火锅');
  }
  return tags.toList();
}
