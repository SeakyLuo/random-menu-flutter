# 随机菜单 · Flutter

RandomMenu 的 Flutter 迁移版本，采用绿色主题、细线图标和参考 Aurai 的液态玻璃胶囊底栏。支持 Android、iOS 和 macOS。

## 运行

使用 Dart 3.12 / Flutter 3.43 开发。Apple 平台需要 Xcode 与 CocoaPods。

```sh
flutter pub get
flutter run
```

## 功能

- 菜谱：搜索与历史、标签管理与筛选、收藏、照片与裁剪、做法、编辑草稿、同名合并。
- 随机菜单：标签偏好及排除、不重复挑选、卡片手势、暂时隐藏及恢复、本次菜单管理。
- 餐厅：分类、多地址、菜单、用餐记录、数量与单价、自动或手动计费、同行人统计、搜索与筛选。
- 照片导入：读取拍摄时间与 GPS、手动补齐时间与分店、按次用餐分组、合并或拆分记录及菜品，再确认入库。地址识别由用户主动触发，需要网络和平台地理编码服务。
- 我的：两类收藏、想做转菜谱、想吃、不喜欢、随手记、明暗外观、字面与表达式自动标签规则。
- 完整 ZIP 备份恢复，包含照片、草稿、设置和菜单；兼容旧 Android 四文件备份及早期单设置文件备份，恢复前展示覆盖范围。

自动标签表达式由 Android 原生 Pattern 或 Apple ICU 引擎验证和匹配。若当前平台不支持某条旧规则，导入会提示失败并保留现有数据，需修改原规则后重新导入。

不预装原仓库个人数据。所有数据保存在应用私有目录，卸载前请导出备份。照片导出和分享使用系统界面，实际可用目标由设备决定。

## 手机数据备份

IDEA 运行配置选择 **备份手机数据到桌面**（Shell Script），运行后生成桌面的 `RandomMenu备份-时间戳` 文件夹。
需连接一台已授权 USB 调试、且已安装可用 `run-as` 的调试版 App 的 Android 手机；不会安装或重启 App。备份期间不要编辑数据。

也可在项目根目录运行：

```sh
./scripts/backup-android-data.sh
```

支持 `--serial 设备序列号` 和 `--output 输出父目录`。包含应用私有数据、设置及应用外部照片目录，校验数据库完整性和照片引用；原始系统相册不包含在内。这是原始目录备份，不是 App 内 ZIP 导入文件。

## 构建验证

```sh
flutter analyze lib
flutter build apk --debug --target-platform android-arm64
flutter build macos --debug
```

当前 Flutter 预览版的 iOS 模拟器多架构命令存在架构参数解析问题；Apple Silicon 上已通过以下单架构原生构建（先运行 `flutter build ios --simulator` 生成配置并安装 Pods）：

```sh
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO \
  BUILD_DIR="$PWD/build/ios"
```

相机、系统照片选择器、分享目标及联网地址识别需要在授权的实际设备上进一步验证。构建成功不代表这些系统交互已经完成真机验收。

## MCP 数据导入导出

开启「我的 → MCP 连接」后，通过原有带 Bearer Token 的 `/mcp` JSON-RPC 接口调用以下工具。ZIP 格式与 App 内「资料导入与备份」一致，包含照片及设置；导入会覆盖全部数据，不是合并。

- 导出：`export_backup({})` 返回 `transferId`、`bytes`、`sha256`。从 `offset: 0` 开始调用 `read_backup_chunk({transferId, offset})`，把返回的 `base64` 解码追加到本地 ZIP，以 `nextOffset` 继续直到 `eof: true`。核对文件大小及 SHA-256 后调用 `delete_backup_transfer({transferId})` 清理手机临时文件。
- 上传：先计算本地 ZIP 的大小及 SHA-256，调用 `begin_backup_import({bytes, sha256})`；每块最多 512 KiB，调用 `write_backup_chunk({transferId, offset, base64})` 顺序上传。连接中断后调用 `preview_backup_import({transferId})` 查询 `receivedBytes`，不要盲目重传已写入的块。
- 预览：上传完成后调用 `preview_backup_import({transferId})`。工具检查校验和及备份格式，返回数量、覆盖范围及 `previewToken`；此时不修改当前资料。让用户审阅并明确授权覆盖。
- 恢复：调用 `import_backup({transferId, previewToken, confirmOverwrite: true})`。恢复前自动创建当前数据的安全备份，返回 `safetyBackup` 的下载信息。预览后当前数据有变化会拒绝覆盖，需重新预览。恢复响应丢失时先查询预览状态并核对当前资料，不要重复恢复。
- 完成后下载安全备份，再清理对应传输文件。未主动清理的传输文件会保留；MCP 配置和 Token 不随备份导出。

导入导出会执行 ZIP 打包、照片读取和完整性校验，大备份可能需要较长时间；客户端超时应按上述进度和状态查询处理。
