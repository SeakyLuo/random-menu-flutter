import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/search_scope.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../media/media_actions.dart';
import '../random/random_recipe_card.dart';

class RecipeSharePage extends StatefulWidget {
  const RecipeSharePage({
    super.key,
    required this.recipe,
    required this.coverPath,
  });

  final Recipe recipe;
  final String? coverPath;

  @override
  State<RecipeSharePage> createState() => _RecipeSharePageState();
}

class _RecipeSharePageState extends State<RecipeSharePage> {
  final _cardKey = GlobalKey();
  late final _cardTheme = menuTheme(Brightness.light);
  late final _coverPath =
      widget.coverPath ?? widget.recipe.imagePaths.firstOrNull;
  late final _cover = _coverPath == null ? null : FileImage(File(_coverPath));
  bool _sharing = false;
  bool _original = true;

  Future<void> _shareOriginal() async {
    final photos = MenuScope.of(context).photos;
    final hasOriginal = await photos.hasOriginal(_coverPath!);
    final path = hasOriginal ? await photos.original(_coverPath) : _coverPath;
    try {
      if (mounted) {
        await sharePhoto(context, path, title: widget.recipe.name);
      }
    } finally {
      if (hasOriginal) await File(path).delete();
    }
  }

  Future<void> _loadCover() async {
    if (_cover == null) return;
    final ready = Completer<void>();
    final stream = _cover.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((image, _) {
      image.dispose();
      ready.complete();
    }, onError: ready.completeError);
    stream.addListener(listener);
    try {
      await ready.future;
    } finally {
      stream.removeListener(listener);
    }
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await performAction(context, () async {
        if (_original) {
          await _shareOriginal();
          return;
        }
        await _loadCover();
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final boundary =
            _cardKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        // Export only the card, at three times its preview resolution.
        final image = await boundary.toImage(pixelRatio: 3);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final temporary = await getTemporaryDirectory();
          final directory = await Directory(
            '${temporary.path}/recipe_cards',
          ).create(recursive: true);
          final file = File('${directory.path}/${newId()}.png');
          await file.writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
            flush: true,
          );
          if (!mounted) return;
          await sharePhoto(context, file.path, title: widget.recipe.name);
        } finally {
          image.dispose();
        }
      });
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Padding(
        padding: const EdgeInsets.only(right: 56),
        child: IgnorePointer(
          ignoring: _sharing,
          child: SearchScope<bool>(
            labels: const {true: '原图', false: '卡片'},
            selected: _original,
            onChanged: (value) => setState(() => _original = value),
          ),
        ),
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: _original
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Center(
                    child: _coverPath == null
                        ? Text(
                            '暂无照片，可切换为卡片分享',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          )
                        : LocalPhoto(path: _coverPath, fit: BoxFit.contain),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(0, constraints.maxHeight - 48),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Theme(
                            data: _cardTheme,
                            child: RepaintBoundary(
                              key: _cardKey,
                              child: AspectRatio(
                                aspectRatio: .8,
                                child: RandomRecipeCard(
                                  recipe: widget.recipe,
                                  coverPath: _coverPath,
                                  showFavorite: false,
                                  fullResolutionPhoto: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sharing || (_original && _coverPath == null)
                  ? null
                  : _share,
              icon: const MenuIcon(Icons.ios_share_rounded, size: 20),
              label: Text(
                _sharing
                    ? '正在分享…'
                    : _original
                    ? '分享原图'
                    : '分享卡片',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
