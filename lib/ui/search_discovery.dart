import 'package:flutter/material.dart';
import 'menu_icon.dart';

class SearchDiscovery extends StatelessWidget {
  const SearchDiscovery({
    super.key,
    required this.libraryEmpty,
    required this.bottom,
    required this.history,
    required this.managing,
    required this.busy,
    required this.onManage,
    required this.onHistory,
    required this.onRemove,
    required this.onClear,
    required this.onCreate,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.createLabel,
  });

  final String emptyTitle, emptyMessage, createLabel;
  final bool libraryEmpty;
  final double bottom;
  final List<String> history;
  final bool managing;
  final bool busy;
  final VoidCallback onManage;
  final ValueChanged<String> onHistory;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SearchEntrance(
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '最近搜索',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (history.isNotEmpty) ...[
                if (managing)
                  TextButton(
                    onPressed: busy ? null : onClear,
                    child: const Text('清空'),
                  ),
                TextButton(
                  onPressed: busy ? null : onManage,
                  child: Text(managing ? '完成' : '管理'),
                ),
              ],
            ],
          ),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '搜索过的关键词会留在这里',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final term in history)
                  _KeywordChip(
                    label: term,
                    onPressed: busy || managing ? null : () => onHistory(term),
                    removable: managing,
                    onDeleted: busy ? null : () => onRemove(term),
                  ),
              ],
            ),
          if (libraryEmpty) ...[
            const SizedBox(height: 40),
            Text(
              emptyTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: onCreate,
                child: Text(createLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchEntrance extends StatelessWidget {
  const _SearchEntrance({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final animation = ModalRoute.of(context)!.animation!.drive(
      CurveTween(curve: const Interval(.12, 1, curve: Curves.easeOutCubic)),
    );
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 24 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({
    required this.label,
    required this.onPressed,
    this.removable = false,
    this.onDeleted,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool removable;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xff273138) : const Color(0xffe9eef1);
    final foreground = dark ? const Color(0xffc4d0d8) : const Color(0xff52616d);
    return InputChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      labelStyle: TextStyle(fontSize: 14, color: foreground),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      backgroundColor: background,
      disabledColor: background,
      side: BorderSide.none,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: onPressed,
      onDeleted: removable ? onDeleted : null,
      deleteButtonTooltipMessage: '删除搜索历史$label',
      deleteIcon: MenuIcon(Icons.close, size: 16, color: foreground),
    );
  }
}
