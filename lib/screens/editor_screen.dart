import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../models/project_state.dart';
import '../models/template_media.dart';
import '../services/overlay_renderer.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';
import '../widgets/draggable_guest_text.dart';
import '../widgets/text_style_panel.dart';

/// Pantalla 1: selección de plantilla + editor visual (WYSIWYG).
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.isActive});

  /// Falso cuando la pestaña no está visible: se pausa el video.
  final bool isActive;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _permissions = const PermissionService();
  VideoPlayerController? _video;
  bool _loading = false;

  @override
  void didUpdateWidget(covariant EditorScreen old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive) {
      final v = _video;
      if (v != null && v.value.isInitialized) {
        widget.isActive ? v.play() : v.pause();
      }
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _pickTemplate() async {
    final project = ProjectScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await _permissions.requestMediaRead();
      final picked = await FilePicker.pickFile(
        type: FileType.media, // galería: imágenes y videos
      );
      final path = picked?.path;
      if (path == null) return;

      final ext = path.split('.').last.toLowerCase();
      TemplateMedia template;

      if (TemplateMedia.videoExtensions.contains(ext)) {
        final controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0); // silenciado en el editor
        final size = controller.value.size;
        template = TemplateMedia(
          path: path,
          type: TemplateType.video,
          width: size.width.round(),
          height: size.height.round(),
          durationMs: controller.value.duration.inMilliseconds,
        );
        await _video?.dispose();
        _video = controller;
        if (widget.isActive) await controller.play();
      } else if (TemplateMedia.imageExtensions.contains(ext)) {
        final size = await OverlayRenderer.imageSize(path);
        template = TemplateMedia(
          path: path,
          type: TemplateType.image,
          width: size.width.round(),
          height: size.height.round(),
        );
        await _video?.dispose();
        _video = null;
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Formato no soportado. Usa MP4, JPG o PNG.')),
        );
        return;
      }
      project.setTemplate(template);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo abrir la plantilla: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ProjectScope.of(context);
    final template = project.template;
    final panelMaxHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor de plantilla'),
        actions: [
          if (template != null)
            TextButton.icon(
              onPressed: _loading ? null : _pickTemplate,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Cambiar'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: template == null
                ? _EmptyPicker(loading: _loading, onPick: _pickTemplate)
                : _Preview(template: template, video: _video),
          ),
          if (template != null)
            Container(
              constraints: BoxConstraints(maxHeight: panelMaxHeight),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(top: BorderSide(color: AppTheme.outline)),
              ),
              child: TextStylePanel(
                config: project.style,
                sampleText: project.sampleText,
                onChanged: project.updateStyle,
                onSampleTextChanged: project.setSampleText,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyPicker extends StatelessWidget {
  const _EmptyPicker({required this.loading, required this.onPick});

  final bool loading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.electricBlue.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.movie_creation_outlined,
                  size: 56, color: AppTheme.electricBlue),
            ),
            const SizedBox(height: 20),
            Text('Elige tu plantilla',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 8),
            const Text(
              'Video MP4 o imagen JPG/PNG de tu galería.\nLuego arrastra el nombre a su lugar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: loading ? null : onPick,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: const Text('Seleccionar de la galería'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.template, required this.video});

  final TemplateMedia template;
  final VideoPlayerController? video;

  @override
  Widget build(BuildContext context) {
    final project = ProjectScope.of(context);

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, box) {
          // Ajuste "contain" conservando la relación de aspecto real.
          final fitted = applyBoxFit(
            BoxFit.contain,
            template.size,
            Size(box.maxWidth, box.maxHeight),
          ).destination;

          Widget media;
          if (template.isVideo && video != null && video!.value.isInitialized) {
            media = VideoPlayer(video!);
          } else if (!template.isVideo) {
            media = Image.file(File(template.path), fit: BoxFit.fill);
          } else {
            media = const Center(child: CircularProgressIndicator());
          }

          return Center(
            child: SizedBox(
              width: fitted.width,
              height: fitted.height,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(child: media),
                  Positioned.fill(
                    child: DraggableGuestText(
                      text: project.sampleText,
                      config: project.style,
                      displaySize: fitted,
                      onChanged: project.updateStyle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
