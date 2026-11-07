import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/widgets.dart';

Future<String?> showRecipeSearchHistory(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _HistorySheet(),
    );

class _HistorySheet extends StatelessWidget {
  const _HistorySheet();
  @override
  Widget build(BuildContext context) {
    final store = MenuScope.of(context);
    final history = store.data.recipeSearchHistory;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '搜索历史',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                if (history.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      if (!await confirmAction(
                        context,
                        title: '清空搜索历史？',
                        message: '清空后无法恢复。',
                        confirmLabel: '清空',
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      await performAction(
                        context,
                        () => store.update(
                          MenuWriteScope.settings,
                          (data) => data.recipeSearchHistory.clear(),
                        ),
                        success: '搜索历史已清空',
                      );
                    },
                    child: const Text('清空'),
                  ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const MenuIcon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text('搜索后，关键词会保留在这里。'))
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (_, index) {
                        final query = history[index];
                        return ListTile(
                          title: Text(query),
                          onTap: () => Navigator.pop(context, query),
                          trailing: IconButton(
                            tooltip: '删除这条历史',
                            icon: const MenuIcon(Icons.close),
                            onPressed: () => performAction(
                              context,
                              () => store.update(
                                MenuWriteScope.settings,
                                (data) =>
                                    data.recipeSearchHistory.remove(query),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
