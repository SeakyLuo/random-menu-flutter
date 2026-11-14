#!/usr/bin/env python3
"""Read-only Android app-directory backup; no install, restart or restore."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tarfile
import tempfile

PACKAGE = 'com.seakyluo.random_menu'
DB = 'files/random_menu/menu.db'


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description='备份 RandomMenu 手机数据到桌面，不安装或重启 App。')
    parser.add_argument('--serial', help='adb 设备序列号；仅连接一台时无需填写')
    parser.add_argument('--output', type=Path, default=Path.home() / 'Desktop', help='备份目录的父目录')
    args = parser.parse_args()
    sdk = Path(os.environ.get('ANDROID_SDK_ROOT', str(Path.home() / 'Library/Android/sdk')))
    adb = shutil.which('adb') or str(sdk / 'platform-tools/adb')

    def adb_text(*parts):
        return subprocess.check_output([adb, *parts], text=True).strip()

    devices = [line.split()[0] for line in adb_text('devices').splitlines()[1:]
               if len(line.split()) == 2 and line.split()[1] == 'device']
    serial = args.serial
    if serial is None:
        if len(devices) != 1:
            raise RuntimeError('请只连接一台已授权手机，或通过 --serial 指定设备。')
        serial = devices[0]
    command = [adb, '-s', serial]

    def device(*parts):
        return subprocess.check_output([*command, *parts], text=True).strip()

    # run-as requires a debuggable build. Failure must not trigger an installation.
    device('shell', 'run-as', PACKAGE, 'pwd')
    stamp = datetime.datetime.now().astimezone().strftime('%Y%m%d-%H%M%S')
    output = args.output.expanduser() / ('RandomMenu备份-' + stamp)
    output.mkdir(parents=True)
    print('备份位置：' + str(output), flush=True)

    def database_state():
        names = device('shell', 'run-as', PACKAGE, 'ls', 'files/random_menu').splitlines()
        files = [DB] + [DB + suffix for suffix in ['-wal', '-journal']
                        if 'menu.db' + suffix in names]
        return device('shell', 'run-as', PACKAGE, 'sha256sum', *files)

    before = database_state()
    archives = [
        ('应用数据.tar', ['exec-out', 'run-as', PACKAGE, 'tar', '-cf', '-',
                        'files', 'shared_prefs', 'app_flutter']),
        ('外部照片.tar', ['exec-out', 'tar', '-C',
                        '/sdcard/Android/data/' + PACKAGE, '-cf', '-', 'files']),
    ]
    members = {}
    for name, parts in archives:
        print('正在备份：' + name, flush=True)
        with (output / name).open('wb') as stream:
            subprocess.run([*command, *parts], stdout=stream, check=True)
        with tarfile.open(output / name) as archive:
            members[name] = set(archive.getnames())
    if before != database_state():
        raise RuntimeError('备份期间数据库发生变化，本次未通过校验。请停止编辑后重新运行。')

    # Read the copied WAL with its database, then produce a standalone SQLite file.
    with tempfile.TemporaryDirectory(prefix='random-menu-backup-') as temporary:
        snapshot = Path(temporary)
        with tarfile.open(output / '应用数据.tar') as archive:
            for name in [DB, DB + '-wal', DB + '-shm', DB + '-journal']:
                if name in members['应用数据.tar']:
                    (snapshot / Path(name).name).write_bytes(archive.extractfile(name).read())
        with sqlite3.connect(snapshot / 'menu.db') as source:
            with sqlite3.connect(output / 'menu.db') as target:
                source.backup(target)
    with sqlite3.connect('file:' + str(output / 'menu.db') + '?mode=ro', uri=True) as database:
        integrity = database.execute('PRAGMA integrity_check').fetchall()
        if integrity != [('ok',)]:
            raise RuntimeError('数据库完整性校验失败：' + repr(integrity))
        tables = ['recipes', 'restaurants', 'restaurant_visits', 'restaurant_visit_items',
                  'restaurant_addresses', 'images', 'restaurant_categories']
        counts = dict(database.execute(' UNION ALL '.join(
            "SELECT '" + table + "', COUNT(*) FROM " + table for table in tables)))
        paths = [row[0] for row in database.execute('SELECT DISTINCT path FROM images')]

    prefixes = [('/data/user/0/' + PACKAGE + '/', '应用数据.tar'),
                ('/data/data/' + PACKAGE + '/', '应用数据.tar'),
                ('/storage/emulated/0/Android/data/' + PACKAGE + '/', '外部照片.tar'),
                ('/sdcard/Android/data/' + PACKAGE + '/', '外部照片.tar')]
    missing, outside = [], []
    for path in paths:
        match = next(((prefix, name) for prefix, name in prefixes if path.startswith(prefix)), None)
        if match is None:
            outside.append(path)
        elif path[len(match[0]):] not in members[match[1]]:
            missing.append(path)
    manifest = dict(createdAt=stamp, device=serial, package=PACKAGE,
                    databaseIntegrity='ok', databaseStableDuringBackup=True,
                    counts=counts, missingPhotoReferences=missing,
                    outsideAppPhotoReferences=outside,
                    files={name: dict(bytes=(output / name).stat().st_size,
                                      sha256=sha256(output / name))
                           for name in ['应用数据.tar', '外部照片.tar', 'menu.db']})
    (output / '校验信息.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    (output / '说明.txt').write_text(
        'RandomMenu 手机原始数据备份\n\n'
        '应用数据.tar：私有数据库、应用照片、设置及其他私有文件。\n'
        '外部照片.tar：应用外部文件目录，包括导入照片。\n'
        'menu.db：合并 WAL 后独立可读的数据库副本。\n'
        '校验信息.json：数量、SHA-256、照片引用及数据库校验结果。\n\n'
        '这不是 App 内 ZIP 导入格式。原始手机相册不包含在此备份中。\n'
        'outsideAppPhotoReferences 列出应用目录外的照片引用，需另行保留其原文件。\n'
        '只有命令输出“备份完成”才代表本次校验通过。\n')
    if missing:
        raise RuntimeError('备份缺少应用照片，详见校验信息.json；本次未通过校验。')
    print('备份完成：' + str(output), flush=True)
    print(json.dumps(counts, ensure_ascii=False), flush=True)
    if outside:
        print(f'另有 {len(outside)} 个应用目录外的照片引用，详见校验信息.json。', flush=True)


if __name__ == '__main__':
    main()
