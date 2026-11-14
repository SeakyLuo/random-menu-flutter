import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../backup/backup_service.dart';

/// ZIP transfers use bounded chunks instead of embedding entire photo archives
/// in a JSON-RPC request. Imports remain staged until explicitly committed.
class MenuMcpBackupTools {
  MenuMcpBackupTools(this.store);
  final MenuStore store;
  static bool _busy = false;
  String get _currentVersion =>
      sha256.convert(utf8.encode(jsonEncode(store.data.toJson()))).toString();
  static const chunkSize = 512 * 1024;
  static const names = [
    'export_backup',
    'read_backup_chunk',
    'begin_backup_import',
    'write_backup_chunk',
    'preview_backup_import',
    'import_backup',
    'delete_backup_transfer',
  ];
  static const _id = {'type': 'string'};
  static const _integer = {'type': 'integer', 'minimum': 0};
  static List<Map<String, Object?>> get definitions => [
    for (final name in names)
      {
        'name': name,
        'description': switch (name) {
          'export_backup' =>
            'Create a complete ZIP backup including photos and settings. Returns transferId, byte size and SHA-256; download using read_backup_chunk. Does not alter app data.',
          'read_backup_chunk' =>
            'Read up to 512 KiB from an exported ZIP as base64. Advance by bytesRead until eof, then verify SHA-256. Call delete_backup_transfer after downloading.',
          'begin_backup_import' =>
            'Stage a ZIP upload. Supply total bytes and SHA-256, then append base64 chunks using write_backup_chunk. Does not import or change app data.',
          'write_backup_chunk' =>
            'Append up to 512 KiB at the exact current byte offset. On connection loss inspect progress using preview_backup_import before retrying. Does not import data.',
          'preview_backup_import' =>
            'Return upload progress. Once complete, verify checksum and ZIP, return content counts and previewToken. Show the overwrite scope to the user before calling import_backup.',
          'import_backup' =>
            'DESTRUCTIVE: replace ALL app data and photos from the previewed ZIP. Requires explicit user authorization, confirmOverwrite=true and the previewToken. Only call after showing the preview. Creates a safety backup of current data before restoring; returns its transferId for download. Never retry blindly after connection loss: read current data first.',
          _ =>
            'Delete staged transfer files only. Does not delete restaurant, recipe or photo data.',
        },
        'annotations': {
          'readOnlyHint':
              name == 'read_backup_chunk' || name == 'preview_backup_import',
          'destructiveHint': name == 'import_backup',
          'openWorldHint': false,
        },
        'inputSchema': {
          'type': 'object',
          'properties': {
            if (name != 'export_backup' && name != 'begin_backup_import')
              'transferId': _id,
            if (name == 'begin_backup_import') ...{
              'bytes': {'type': 'integer', 'minimum': 1, 'maximum': 2147483648},
              'sha256': {'type': 'string', 'pattern': '^[a-f0-9]{64}\$'},
            },
            if (name == 'read_backup_chunk' || name == 'write_backup_chunk')
              'offset': _integer,
            if (name == 'write_backup_chunk')
              'base64': {'type': 'string', 'maxLength': 699052},
            if (name == 'import_backup') ...{
              'previewToken': _id,
              'confirmOverwrite': {
                'type': 'boolean',
                'enum': [true],
              },
            },
          },
          'required': [
            if (name != 'export_backup' && name != 'begin_backup_import')
              'transferId',
            if (name == 'begin_backup_import') ...['bytes', 'sha256'],
            if (name == 'read_backup_chunk' || name == 'write_backup_chunk')
              'offset',
            if (name == 'write_backup_chunk') 'base64',
            if (name == 'import_backup') ...[
              'previewToken',
              'confirmOverwrite',
            ],
          ],
          'additionalProperties': false,
        },
      },
  ];

  Directory get _directory =>
      Directory('${store.directory.path}/mcp_transfers');

  File _file(String id, String extension) {
    if (!RegExp(r'^[a-zA-Z0-9-]{1,80}$').hasMatch(id)) {
      throw ArgumentError('Invalid transferId');
    }
    return File('${_directory.path}/$id.$extension');
  }

  Future<Map<String, dynamic>> _metadata(String id) async =>
      jsonDecode(await _file(id, 'json').readAsString())
          as Map<String, dynamic>;

  Future<void> _save(String id, Map<String, dynamic> metadata) =>
      _file(id, 'json').writeAsString(jsonEncode(metadata), flush: true);

  Future<String> _digest(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<Map<String, Object?>> _export() async {
    final id = newId();
    await _directory.create(recursive: true);
    final bytes = await BackupService.export(store.data);
    await _file(id, 'zip').writeAsBytes(bytes, flush: true);
    final metadata = {
      'direction': 'export',
      'bytes': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
    };
    await _save(id, metadata);
    return {'transferId': id, ...metadata, 'chunkSize': chunkSize};
  }

  Future<Map<String, Object?>> call(
    String name,
    Map<String, dynamic> args,
  ) async {
    if (_busy) throw StateError('Another backup transfer operation is running');
    _busy = true;
    try {
      return await _call(name, args);
    } finally {
      _busy = false;
    }
  }

  Future<Map<String, Object?>> _call(
    String name,
    Map<String, dynamic> args,
  ) async {
    if (name == 'export_backup') return _export();
    if (name == 'begin_backup_import') {
      final size = args['bytes'] as int;
      final hash = args['sha256'] as String;
      if (size < 1 ||
          size > 2147483648 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        throw ArgumentError('Invalid backup size or SHA-256');
      }
      final id = newId();
      await _directory.create(recursive: true);
      await _file(id, 'zip').create();
      await _save(id, {'direction': 'import', 'bytes': size, 'sha256': hash});
      return {'transferId': id, 'chunkSize': chunkSize, 'receivedBytes': 0};
    }
    final id = args['transferId'] as String;
    final metadata = await _metadata(id);
    final file = _file(id, 'zip');
    if (name == 'delete_backup_transfer') {
      await file.delete();
      await _file(id, 'json').delete();
      return {'deleted': true};
    }
    if (name == 'read_backup_chunk') {
      if (metadata['direction'] != 'export') {
        throw StateError('Not an export transfer');
      }
      final offset = args['offset'] as int;
      final length = await file.length();
      if (offset < 0 || offset > length) throw ArgumentError('Invalid offset');
      final handle = await file.open();
      try {
        await handle.setPosition(offset);
        final bytes = await handle.read(chunkSize);
        return {
          'base64': base64Encode(bytes),
          'bytesRead': bytes.length,
          'nextOffset': offset + bytes.length,
          'eof': offset + bytes.length == length,
        };
      } finally {
        await handle.close();
      }
    }
    if (name == 'preview_backup_import' && metadata['status'] == 'restored') {
      return {'restored': true, 'safetyBackup': metadata['safetyBackup']};
    }
    if (metadata['direction'] != 'import' || metadata['status'] == 'restored') {
      throw StateError('Transfer is not an active import');
    }
    if (name == 'write_backup_chunk') {
      final bytes = base64Decode(args['base64'] as String);
      final length = await file.length();
      if (args['offset'] != length ||
          bytes.isEmpty ||
          bytes.length > chunkSize ||
          length + bytes.length > (metadata['bytes'] as int)) {
        throw ArgumentError(
          'Invalid chunk or offset; inspect receivedBytes before retrying',
        );
      }
      await file.writeAsBytes(bytes, mode: FileMode.append, flush: true);
      return {
        'receivedBytes': length + bytes.length,
        'totalBytes': metadata['bytes'],
      };
    }
    final received = await file.length();
    if (received != metadata['bytes']) {
      if (name != 'preview_backup_import') {
        throw StateError('Upload is incomplete');
      }
      return {
        'complete': false,
        'receivedBytes': received,
        'totalBytes': metadata['bytes'],
      };
    }
    if (await _digest(file) != metadata['sha256']) {
      throw const FormatException('Backup SHA-256 mismatch');
    }
    final backup = await BackupService.read(await file.readAsBytes());
    if (name == 'preview_backup_import') {
      final token = newId();
      await _save(id, {
        ...metadata,
        'previewToken': token,
        'currentVersion': _currentVersion,
      });
      return {
        'complete': true,
        'previewToken': token,
        'summary': backup.summary,
        'recipes': backup.data.recipes.length,
        'restaurants': backup.data.restaurants.length,
        'visits': backup.data.restaurants.fold<int>(
          0,
          (count, r) => count + r.records.length,
        ),
        'photos': backup.photos.length,
        'overwriteScope': '全部菜谱、餐厅、消费记录、照片、收藏、清单、草稿、标签规则、搜索历史、设置和本次菜单',
      };
    }
    if (name != 'import_backup') throw ArgumentError.value(name);
    if (args['confirmOverwrite'] != true ||
        metadata['previewToken'] == null ||
        args['previewToken'] != metadata['previewToken']) {
      throw StateError(
        'Preview and explicit overwrite confirmation are required',
      );
    }
    void checkCurrent() {
      if (_currentVersion != metadata['currentVersion']) {
        throw StateError(
          'Current data changed after preview; preview again before restoring',
        );
      }
    }

    checkCurrent();
    final safety = await _export();
    await BackupService.restore(store, backup, checkCurrent: checkCurrent);
    await _save(id, {
      ...metadata,
      'status': 'restored',
      'safetyBackup': safety,
    });
    return {'restored': true, 'safetyBackup': safety};
  }
}
