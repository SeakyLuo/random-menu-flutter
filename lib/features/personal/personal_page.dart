import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_settings_section.dart';
import '../../ui/widgets.dart';
import '../backup/backup_page.dart';
import '../mcp/menu_mcp_page.dart';
import 'appearance_page.dart';
import 'personal_collections.dart';
import 'personal_note_page.dart';
import 'tag_rules_page.dart';

class PersonalPage extends StatelessWidget {
  const PersonalPage({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;
  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    return MenuPage(
      title: '我的',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          100 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          _group(context, '饮食清单', [
            _entry(
              context,
              Icons.favorite_border,
              '我的收藏',
              onTap: () => _open(
                context,
                FavoritesPage(
                  onBrowseRecipes: () => onNavigate(1),
                  onBrowseRestaurants: () => onNavigate(2),
                ),
              ),
            ),
            _entry(
              context,
              Icons.soup_kitchen_outlined,
              '想做',
              value: '${data.toCook.length}',
              onTap: () => _open(
                context,
                const PersonalListPage(kind: PersonalListKind.toCook),
              ),
            ),
            _entry(
              context,
              Icons.storefront_outlined,
              '想吃',
              value: '${data.toEat.length}',
              onTap: () => _open(
                context,
                const PersonalListPage(kind: PersonalListKind.toEat),
              ),
            ),
            _entry(
              context,
              Icons.do_not_disturb_alt_outlined,
              '不喜欢',
              value: '${data.dislikes.length}',
              onTap: () => _open(
                context,
                const PersonalListPage(kind: PersonalListKind.dislikes),
              ),
            ),
            _entry(
              context,
              Icons.edit_note,
              '随手记',
              onTap: () => _open(context, const PersonalNotePage()),
            ),
          ]),
          _group(context, '偏好设置', [
            _entry(
              context,
              Icons.link,
              'MCP 连接',
              detail: '让AI管理菜谱、餐厅和探店记录',
              onTap: () => _open(context, const MenuMcpPage()),
            ),
            _entry(
              context,
              Icons.palette_outlined,
              '外观',
              value: switch (data.themeMode) {
                'light' => '浅色',
                'dark' => '深色',
                _ => '跟随系统',
              },
              onTap: () => _open(context, const AppearancePage()),
            ),
            _entry(
              context,
              Icons.auto_awesome_outlined,
              '自动标签',
              value: data.autoTag
                  ? '${data.tagRules.length + data.patternTagRules.length} 条规则'
                  : '已关闭',
              onTap: () => _open(context, const TagRulesPage()),
            ),
          ]),
          _group(context, '数据管理', [
            _entry(
              context,
              Icons.inventory_2_outlined,
              '资料导入与备份',
              detail: '导入菜谱、餐厅、记录和照片，也可保存备份',
              onTap: () => _open(context, const BackupPage()),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, String title, List<Widget> entries) =>
      MenuSettingsSection(title: title, children: entries);
  Widget _entry(
    BuildContext context,
    IconData icon,
    String title, {
    String? value,
    String? detail,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          MenuIcon(
            icon,
            size: 22,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .72),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, height: 1.5)),
                if (detail != null)
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(width: 12),
          MenuIcon(
            Icons.chevron_right,
            size: 17,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    ),
  );
}
