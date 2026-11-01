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
- 餐厅：分类、多分店地址、菜单、用餐记录、数量与单价、自动或手动计费、同行人统计、搜索与筛选。
- 照片导入：读取拍摄时间与 GPS、手动补齐时间与分店、按次用餐分组、合并或拆分记录及菜品，再确认入库。地址识别由用户主动触发，需要网络和平台地理编码服务。
- 我的：两类收藏、想做转菜谱、想吃、不喜欢、随手记、明暗外观、字面与表达式自动标签规则。
- 完整 ZIP 备份恢复，包含照片、草稿、设置和菜单；兼容旧 Android 四文件备份及早期单设置文件备份，恢复前展示覆盖范围。

自动标签表达式由 Android 原生 Pattern 或 Apple ICU 引擎验证和匹配。若当前平台不支持某条旧规则，导入会提示失败并保留现有数据，需修改原规则后重新导入。

不预装原仓库个人数据。所有数据保存在应用私有目录，卸载前请导出备份。照片导出和分享使用系统界面，实际可用目标由设备决定。

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
