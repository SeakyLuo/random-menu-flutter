import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/menu_store.dart';
import 'menu_mcp_tools.dart';

class MenuMcpConfig {
  const MenuMcpConfig({
    required this.enabled,
    required this.port,
    required this.token,
  });
  final bool enabled;
  final int port;
  final String token;
  String get endpoint => 'http://127.0.0.1:$port/mcp';
  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'port': port,
    'token': token,
  };
  factory MenuMcpConfig.fromJson(Map json) => MenuMcpConfig(
    enabled: json['enabled'] as bool,
    port: json['port'] as int,
    token: json['token'] as String,
  );
}

class MenuMcpServer extends ChangeNotifier {
  MenuMcpServer._(this.store, this.config);
  static late MenuMcpServer instance;
  static const native = MethodChannel('com.seakyluo.random_menu/mcp');
  static const protocol = '2025-11-25';
  final MenuStore store;
  MenuMcpConfig config;
  HttpServer? _server;
  bool get running => _server != null;
  File get _file => File('${store.directory.path}/mcp.json');
  String? startupError;
  bool _changing = false;

  static Future<MenuMcpServer> open(MenuStore store) async {
    final file = File('${store.directory.path}/mcp.json');
    final config = await file.exists()
        ? MenuMcpConfig.fromJson(jsonDecode(await file.readAsString()) as Map)
        : MenuMcpConfig(
            enabled: false,
            port: 52147,
            token: base64UrlEncode(
              List<int>.generate(32, (_) => Random.secure().nextInt(256)),
            ),
          );
    final server = MenuMcpServer._(store, config);
    instance = server;
    if (!await file.exists()) await server._persist(config);
    native.setMethodCallHandler((call) async {
      if (call.method != 'stop') throw MissingPluginException(call.method);
      await server.configure(
        MenuMcpConfig(
          enabled: false,
          port: server.config.port,
          token: server.config.token,
        ),
      );
    });
    return server;
  }

  Future<void> startConfiguredConnection() async {
    if (config.enabled) {
      // Startup is a UI boundary: keep configuration editable on bind failure.
      try {
        await configure(config);
      } on Object catch (error) {
        startupError = error.toString();
      }
    }
  }

  Future<void> _persist(MenuMcpConfig value) async {
    final temporary = File('${_file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value.toJson()), flush: true);
    await temporary.rename(_file.path);
  }

  Future<void> configure(MenuMcpConfig next) async {
    if (_changing) throw StateError('MCP connection settings are being saved.');
    if (next.port < 1024 || next.port > 65535) {
      throw ArgumentError('端口应为 1024–65535');
    }
    _changing = true;
    HttpServer? replacement;
    final previous = _server;
    try {
      if (next.enabled && (previous == null || config.port != next.port)) {
        replacement = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          next.port,
        );
      }
      if (Platform.isAndroid) {
        await native.invokeMethod<void>('setEnabled', {
          'enabled': next.enabled,
        });
      }
      await _persist(next);
      replacement?.listen((request) => unawaited(_serve(request, next.token)));
      if (replacement != null || !next.enabled) {
        _server = replacement;
        await previous?.close(force: true);
      }
      config = next;
      startupError = null;
      notifyListeners();
    } on Object {
      await replacement?.close(force: true);
      if (Platform.isAndroid) {
        await native.invokeMethod<void>('setEnabled', {
          'enabled': previous != null,
        });
      }
      rethrow;
    } finally {
      _changing = false;
    }
  }

  Future<void> _serve(HttpRequest request, String token) async {
    final response = request.response;
    Object? id;
    try {
      if (request.uri.path != '/mcp') {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (request.headers.value(HttpHeaders.authorizationHeader) !=
          'Bearer $token') {
        response.statusCode = HttpStatus.unauthorized;
        response.write('Unauthorized');
        return;
      }
      final origin = request.headers.value('origin');
      if (origin != null) {
        final uri = Uri.parse(origin);
        if (!['localhost', '127.0.0.1', '[::1]', '::1'].contains(uri.host)) {
          response.statusCode = HttpStatus.forbidden;
          return;
        }
      }
      if (request.method != 'POST') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set('Allow', 'POST');
        return;
      }
      if (request.headers.contentType?.mimeType != 'application/json') {
        response.statusCode = HttpStatus.unsupportedMediaType;
        return;
      }
      final bytes = <int>[];
      await for (final chunk in request) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          response.statusCode = HttpStatus.requestEntityTooLarge;
          return;
        }
        bytes.addAll(chunk);
      }
      final rpc = jsonDecode(utf8.decode(bytes)) as Map;
      id = rpc['id'];
      if (rpc['jsonrpc'] != '2.0' || rpc['method'] is! String) {
        throw const FormatException('Invalid JSON-RPC request');
      }
      if (!rpc.containsKey('id')) {
        response.statusCode = HttpStatus.accepted;
        return;
      }
      final suppliedVersion = request.headers.value('MCP-Protocol-Version');
      if (suppliedVersion != null && suppliedVersion != protocol) {
        response.statusCode = HttpStatus.badRequest;
        response.write('Unsupported MCP-Protocol-Version: $suppliedVersion');
        return;
      }
      final tools = MenuMcpTools(store);
      final result = switch (rpc['method']) {
        'initialize' => {
          'protocolVersion': protocol,
          'capabilities': {'tools': <String, Object?>{}},
          'serverInfo': {
            'name': 'random-menu',
            'title': '随机菜单',
            'version': '1.0.0',
          },
          'instructions':
              '管理用户的菜谱、餐厅和探店记录。优先使用已有业务工具，先搜索再读取，修改/删除传入version。只有现有工具无法表达需求时才使用SQL兜底：先inspect_database了解表与JSON字段，query_sql读取实际数据，execute_sql维护关联；禁止擅自改变表结构。只有用户要求时才能修改或删除。',
        },
        'ping' => <String, Object?>{},
        'tools/list' => {'tools': tools.definitions},
        'tools/call' => await _call(tools, rpc['params'] as Map),
        _ => throw UnsupportedError('Method not found: ${rpc['method']}'),
      };
      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}),
      );
    } on Object catch (error) {
      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'error': {
            'code': error is UnsupportedError
                ? -32601
                : error is FormatException
                ? -32700
                : -32602,
            'message': error.toString(),
          },
        }),
      );
    } finally {
      await response.close();
    }
  }

  Future<Map<String, Object?>> _call(MenuMcpTools tools, Map params) async {
    try {
      final output = await tools.call(
        params['name'] as String,
        (params['arguments'] as Map).cast<String, dynamic>(),
      );
      return {
        'content': [
          {'type': 'text', 'text': jsonEncode(output)},
        ],
        'structuredContent': output,
        'isError': false,
      };
    } on Object catch (error) {
      return {
        'content': [
          {'type': 'text', 'text': error.toString()},
        ],
        'isError': true,
      };
    }
  }
}
