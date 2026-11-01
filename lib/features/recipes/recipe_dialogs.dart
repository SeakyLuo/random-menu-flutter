import 'package:flutter/material.dart';
import '../../ui/widgets.dart';

Future<List<String>?> chooseMergeTags(
  BuildContext context,
  List<String> tags,
) => showModalBottomSheet<List<String>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _MergeTags(tags: tags),
);

class _MergeTags extends StatefulWidget {
  const _MergeTags({required this.tags});
  final List<String> tags;
  @override
  State<_MergeTags> createState() => _MergeTagsState();
}

class _MergeTagsState extends State<_MergeTags> {
  late final _selected = widget.tags.take(10).toSet();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('选择合并后保留的标签', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text('两份菜谱的标签超过上限，请保留 1–10 个（已选 ${_selected.length} 个）。'),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in widget.tags)
                    FilterChip(
                      label: Text(tag),
                      selected: _selected.contains(tag),
                      onSelected: (selected) {
                        if (selected && _selected.length == 10) {
                          showToast(context, '最多保留10个标签，请先取消其他标签');
                          return;
                        }
                        setState(() {
                          selected ? _selected.add(tag) : _selected.remove(tag);
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected.toList()),
            child: const Text('使用所选标签并合并'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('返回编辑'),
          ),
        ],
      ),
    ),
  );
}
