import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';

class PersonalNotePage extends StatefulWidget {
  const PersonalNotePage({super.key});
  @override
  State<PersonalNotePage> createState() => _PersonalNotePageState();
}

class _PersonalNotePageState extends State<PersonalNotePage> {
  late final TextEditingController _text;
  final _scroll = ScrollController();
  late String _baseline;
  bool _initialized = false;
  bool _saving = false;
  bool _leaving = false;
  bool get _dirty => _text.text != _baseline;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _baseline = MenuScope.of(context).data.note;
      _text = TextEditingController(text: _baseline)
        ..addListener(() => setState(() {}));
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_saving) return;
    if (_dirty &&
        !await confirmAction(
          context,
          title: '放弃未保存的修改？',
          message: '随手记的这次修改尚未保存。',
          confirmLabel: '放弃修改',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    Navigator.pop(context);
  }

  Future<void> _save() async {
    final value = _text.text;
    setState(() => _saving = true);
    final saved = await performAction(
      context,
      () => MenuScope.of(
        context,
      ).update(MenuWriteScope.settings, (d) => d.note = value),
      success: '随手记已保存',
    );
    if (!mounted) return;
    if (saved) {
      setState(() {
        _baseline = value;
        _leaving = true;
      });
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving || (!_dirty && !_saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: MenuScrollTitle(controller: _scroll, child: const Text('随手记')),
        leading: IconButton(
          tooltip: '返回',
          onPressed: _saving ? null : _leave,
          icon: const MenuIcon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    scrollController: _scroll,
                    enabled: !_saving,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(height: 1.9),
                    decoration: InputDecoration(
                      hintText: '采购清单、做菜灵感，或今天的用餐心情…',
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).inputDecorationTheme.fillColor
                          : Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: !_dirty || _saving ? null : _save,
                      child: Text(_saving ? '保存中…' : '保存'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
