import 'package:flutter/material.dart';
import '../../ui/widgets.dart';
import '../media/media_actions.dart';
import 'import_models.dart';

class SplitVisitPage extends StatefulWidget {
  const SplitVisitPage({super.key, required this.photos});
  final List<ImportPhoto> photos;
  @override
  State<SplitVisitPage> createState() => _SplitVisitPageState();
}

class _SplitVisitPageState extends State<SplitVisitPage> {
  final selected = <int>{};
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('拆分用餐记录')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      children: [
        Text('勾选属于另一次用餐的照片', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text(
          '两次用餐各保留至少一张照片。拍摄时间和分店不变，按各组最早照片的真实时间建立记录。',
          style: TextStyle(height: 1.6),
        ),
        const SizedBox(height: 12),
        const Text(
          '拆分将按原照片设置重新生成菜品明细；之前在预览中调整的菜品合并、单价、份数和照片编辑不会保留，需要重新核对。',
          style: TextStyle(height: 1.6),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < widget.photos.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Checkbox(
                  value: selected.contains(i),
                  onChanged: (value) => setState(() {
                    if (value!) {
                      selected.add(i);
                    } else {
                      selected.remove(i);
                    }
                  }),
                ),
                SizedBox(
                  width: 64,
                  height: 72,
                  child: InkWell(
                    onTap: () => showPhotoViewer(
                      context,
                      widget.photos.map((p) => p.path).toList(),
                      i,
                    ),
                    child: LocalPhoto(path: widget.photos[i].path),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${widget.photos[i].kind == ImportPhotoKind.dish ? widget.photos[i].name : '环境照片'}\n${dayLabel(widget.photos[i].date!)} ${TimeOfDay.fromDateTime(widget.photos[i].date!).format(context)}',
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed:
              selected.isNotEmpty && selected.length < widget.photos.length
              ? () => Navigator.pop(context, [
                  for (final i in selected) widget.photos[i],
                ])
              : null,
          child: Text('将 ${selected.length} 张照片拆为另一次用餐'),
        ),
      ],
    ),
  );
}
