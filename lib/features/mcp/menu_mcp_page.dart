import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_settings_section.dart';
import '../../ui/widgets.dart';
import 'menu_mcp_server.dart';

class MenuMcpPage extends StatefulWidget {
  const MenuMcpPage({super.key});
  @override
  State<MenuMcpPage> createState() => _MenuMcpPageState();
}

class _MenuMcpPageState extends State<MenuMcpPage> {
  final _server = MenuMcpServer.instance;
  late final _port = TextEditingController(text: '${_server.config.port}');
  late bool _enabled = _server.config.enabled;
  bool _saving = false, _leaving = false;
  bool get _dirty =>
      _enabled != _server.config.enabled ||
      _port.text != '${_server.config.port}';

  @override
  void initState() {
    super.initState();
    _port.addListener(_changed);
    _server.addListener(_serverChanged);
  }

  void _changed() => setState(() {});
  void _serverChanged() {
    if (!_saving) {
      _enabled = _server.config.enabled;
      _port.text = '${_server.config.port}';
    }
    setState(() {});
  }

  @override
  void dispose() {
    _server.removeListener(_serverChanged);
    _port.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final port = int.tryParse(_port.text);
    if (port == null || port < 1024 || port > 65535) {
      showToast(context, '端口应为 1024–65535');
      return;
    }
    setState(() => _saving = true);
    final ok = await performAction(
      context,
      () => _server.configure(
        MenuMcpConfig(
          enabled: _enabled,
          port: port,
          token: _server.config.token,
        ),
      ),
      success: 'MCP 设置已保存',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      FocusScope.of(context).unfocus();
      setState(() => _leaving = true);
      Navigator.pop(context);
    }
  }

  Future<void> _leave() async {
    if (_saving) return;
    if (_dirty &&
        !await confirmAction(
          context,
          title: '放弃未保存的修改？',
          message: 'MCP 连接仍将使用已保存的设置。',
          confirmLabel: '放弃修改',
        )) {
      return;
    }
    if (mounted) {
      setState(() => _leaving = true);
      Navigator.pop(context);
    }
  }

  Future<void> _copy(String value) async {
    if (_dirty) {
      showToast(context, '请先保存连接设置');
      return;
    }
    await performAction(
      context,
      () => Clipboard.setData(ClipboardData(text: value)),
      success: '已复制',
    );
  }

  Widget _connectionRow(String title, String value, String copiedValue) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '复制$title',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: _saving ? null : () => _copy(copiedValue),
              icon: MenuIcon(
                Icons.copy,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );

  InputDecoration _portDecoration(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: '52147',
      filled: dark,
      border: dark ? null : InputBorder.none,
      enabledBorder: dark ? null : InputBorder.none,
      focusedBorder: dark ? null : InputBorder.none,
      contentPadding: EdgeInsets.symmetric(
        horizontal: dark ? 12 : 0,
        vertical: 14,
      ),
    );
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
        title: const Text('MCP 连接'),
        leading: IconButton(
          onPressed: _saving ? null : _leave,
          tooltip: '返回',
          icon: const MenuIcon(Icons.arrow_back),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中…' : '保存'),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              MenuSettingsSection(
                title: '连接设置',
                dividerInset: 18,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
                    title: const Text(
                      '允许 AI 连接',
                      style: TextStyle(fontSize: 16, height: 1.5),
                    ),
                    subtitle: Text(
                      '可管理菜谱、餐厅和探店记录',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: _enabled,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _enabled = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '端口',
                            style: TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ),
                        SizedBox(
                          width: 112,
                          child: Semantics(
                            label: '端口',
                            child: TextField(
                              controller: _port,
                              enabled: !_saving,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 14),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _portDecoration(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              MenuSettingsSection(
                title: '连接信息',
                dividerInset: 18,
                children: [
                  _connectionRow(
                    '地址',
                    _server.config.endpoint,
                    _server.config.endpoint,
                  ),
                  _connectionRow('令牌', '••••••••', _server.config.token),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '在 Aurai「设置 → MCP」添加连接，粘贴地址和令牌。连接仅限本机使用。\n\n'
                  '${Platform.isAndroid ? '开启后可通过通知关闭连接。' : '请保持随机菜单运行。'}'
                  '若系统结束应用，请重新打开随机菜单。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
