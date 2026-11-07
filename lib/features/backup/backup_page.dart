import '../../ui/menu_icon.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/widgets.dart';
import 'backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;
  String _progress = '';
  Future<void> _export() async {
    final store = MenuScope.of(context);
    setState(() {
      _busy = true;
      _progress = '正在打包备份';
    });
    await performAction(context, () async {
      final bytes = await BackupService.export(store.data);
      final date = DateTime.now();
      final result = await FilePicker.saveFile(
        fileName:
            '随机菜单_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: bytes,
      );
      if (result != null && mounted) showToast(context, '备份已保存');
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _import() async {
    final store = MenuScope.of(context);
    setState(() {
      _busy = true;
      _progress = '正在读取备份';
    });
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
      if (picked == null) return;
      final backup = await BackupService.read(picked.files.single.bytes!);
      if (!mounted) return;
      final confirmed = await confirmAction(
        context,
        title: '使用此备份覆盖当前数据？',
        message:
            '${backup.summary}\n\n'
            '将覆盖当前菜谱、餐厅、菜品、用餐记录、收藏、所有清单、草稿、标签规则、'
            '搜索历史、随手记、设置、本次菜单和照片。\n\n'
            '当前内容将被替换。建议先导出当前数据。',
        confirmLabel: '覆盖并恢复',
      );
      if (!confirmed) return;
      if (mounted) setState(() => _progress = '正在恢复数据和照片');
      await BackupService.restore(store, backup);
      if (mounted) showToast(context, '备份已恢复');
    } on FormatException catch (error) {
      if (mounted) {
        showToast(
          context,
          error.message.startsWith('请选择') || error.message.startsWith('备份')
              ? error.message
              : '备份格式不正确，当前数据已保留',
        );
      }
    } catch (error, stack) {
      debugPrint('Backup restore failed: $error\n$stack');
      if (mounted) showToast(context, '恢复失败，当前数据已保留');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(titleSpacing: 0, title: const Text('资料导入与备份')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
        children: [
          const Text(
            '导入菜谱、餐厅、用餐记录和照片，或导出一份完整备份。',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const MenuIcon(Icons.ios_share_rounded),
            label: const Text('导出完整备份'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const MenuIcon(Icons.file_download_outlined),
            label: const Text('从备份恢复'),
          ),
          const SizedBox(height: 18),
          Text(
            '支持本应用完整备份，以及原 Android 版导出的两种备份格式。照片与草稿会一并保留。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 32),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(_progress),
          ],
        ],
      ),
    ),
  );
}
