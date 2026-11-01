import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';

import '../../core/menu_store.dart';
import '../../ui/widgets.dart';
import '../backup/backup_page.dart';
import 'personal_collections.dart';
import 'tag_rules_page.dart';

class PersonalPage extends StatelessWidget {
  const PersonalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    return MenuPage(
      title: '我的',
      subtitle: '收好喜欢的味道，记下下一次期待',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const SectionTitle('饮食清单'),
          _entry(
            context,
            Icons.favorite_border,
            '我的收藏',
            '${data.recipes.where((r) => r.favorite).length} 道菜谱 · ${data.restaurants.where((r) => r.favorite).length} 家餐厅',
            const FavoritesPage(),
          ),
          _entry(
            context,
            Icons.soup_kitchen_outlined,
            '想做',
            '${data.toCook.length} 道想亲手做的菜',
            const PersonalListPage(kind: PersonalListKind.toCook),
          ),
          _entry(
            context,
            Icons.restaurant_outlined,
            '想吃',
            '${data.toEat.length} 个惦记的味道',
            const PersonalListPage(kind: PersonalListKind.toEat),
          ),
          _entry(
            context,
            Icons.do_not_disturb_alt_outlined,
            '不喜欢',
            '${data.dislikes.length} 条饮食偏好记录',
            const PersonalListPage(kind: PersonalListKind.dislikes),
          ),
          _entry(
            context,
            Icons.edit_note,
            '随手记',
            data.note.isEmpty ? '记下灵感、采购清单和用餐心情' : '查看和编辑你的记录',
            const PersonalNotePage(),
          ),
          const SectionTitle('偏好设置'),
          Card(
            child: ListTile(
              leading: const MenuIcon(Icons.palette_outlined),
              title: const Text('外观'),
              subtitle: Text(switch (data.themeMode) {
                'light' => '浅色',
                'dark' => '深色',
                _ => '跟随系统',
              }),
              trailing: const MenuIcon(Icons.chevron_right),
              onTap: () => _appearance(context),
            ),
          ),
          _entry(
            context,
            Icons.auto_awesome_outlined,
            '自动标签',
            data.autoTag
                ? '已开启 · ${data.tagRules.length + data.patternTagRules.length} 条规则'
                : '已关闭',
            const TagRulesPage(),
          ),
          const SectionTitle('数据管理'),
          _entry(
            context,
            Icons.inventory_2_outlined,
            '数据备份',
            '保存备份，或从备份恢复菜谱和记录',
            const BackupPage(),
          ),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget page,
  ) => Card(
    child: ListTile(
      leading: MenuIcon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const MenuIcon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page)),
    ),
  );

  Future<void> _appearance(BuildContext context) async {
    final store = MenuScope.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('外观'),
        children: [
          for (final item in const [
            ('system', '跟随系统'),
            ('light', '浅色'),
            ('dark', '深色'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item.$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(item.$2)),
                    if (store.data.themeMode == item.$1)
                      const MenuIcon(Icons.check),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    await performAction(
      context,
      () => store.update((draft) => draft.themeMode = choice),
      success: '外观已更新',
    );
  }
}

class PersonalNotePage extends StatefulWidget {
  const PersonalNotePage({super.key});
  @override
  State<PersonalNotePage> createState() => _PersonalNotePageState();
}

class _PersonalNotePageState extends State<PersonalNotePage> {
  TextEditingController? _controller;
  late final String _initialNote;
  bool _saving = false;
  bool _leaving = false;
  bool get _changed => _controller!.text != _initialNote;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      _initialNote = MenuScope.of(context).data.note;
      _controller = TextEditingController(text: _initialNote)
        ..addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving || (!_changed && !_saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('随手记'),
        leading: IconButton(
          tooltip: '返回',
          onPressed: _saving ? null : _leave,
          icon: const MenuIcon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: TextField(
          controller: _controller,
          enabled: !_saving,
          expands: true,
          maxLines: null,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: '采购清单、做菜灵感，或今天的用餐心情…',
            border: InputBorder.none,
          ),
        ),
      ),
    ),
  );

  Future<void> _leave() async {
    if (_saving) return;
    if (_changed &&
        !await confirmAction(
          context,
          title: '放弃此次编辑？',
          message: '还未保存的随手记修改将丢失。',
          confirmLabel: '放弃修改',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    Navigator.pop(context);
  }

  Future<void> _save() async {
    final store = MenuScope.of(context);
    final note = _controller!.text;
    setState(() => _saving = true);
    final saved = await performAction(
      context,
      () => store.update((draft) => draft.note = note),
      success: '随手记已保存',
    );
    if (!mounted) return;
    if (saved) {
      setState(() => _leaving = true);
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }
}
