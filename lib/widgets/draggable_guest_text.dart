import 'package:flutter/widgets.dart';

import '../models/text_style_config.dart';
import '../services/overlay_renderer.dart';
import '../theme/app_theme.dart';

/// Texto arrastrable sobre la plantilla. Guarda la posición como porcentaje
/// (0..1) del tamaño mostrado, que equivale al % del tamaño real del medio.
class DraggableGuestText extends StatefulWidget {
  const DraggableGuestText({
    super.key,
    required this.text,
    required this.config,
    required this.displaySize,
    required this.onChanged,
  });

  final String text;
  final TextStyleConfig config;

  /// Tamaño en pantalla del medio (video/imagen) sobre el que se arrastra.
  final Size displaySize;
  final ValueChanged<TextStyleConfig> onChanged;

  @override
  State<DraggableGuestText> createState() => _DraggableGuestTextState();
}

class _DraggableGuestTextState extends State<DraggableGuestText> {
  static const double _snap = 0.015; // imán al centro horizontal

  double _rawX = 0.5;
  double _rawY = 0.5;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.displaySize;
    final cfg = widget.config;
    final l = OverlayRenderer.layout(
      text: widget.text.isEmpty ? ' ' : widget.text,
      config: cfg,
      mediaWidth: size.width,
    );
    final tl = OverlayRenderer.topLeft(l, cfg, size);
    final centered = (cfg.xPct - 0.5).abs() < 0.0005;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_dragging && centered)
          Positioned(
            left: size.width / 2 - 0.5,
            top: 0,
            bottom: 0,
            child: Container(width: 1, color: AppTheme.electricBlue),
          ),
        Positioned(
          left: tl.dx,
          top: tl.dy,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) {
              _rawX = cfg.xPct;
              _rawY = cfg.yPct;
              setState(() => _dragging = true);
            },
            onPanUpdate: (d) {
              _rawX = (_rawX + d.delta.dx / size.width).clamp(0.0, 1.0);
              _rawY = (_rawY + d.delta.dy / size.height).clamp(0.0, 1.0);
              final x = (_rawX - 0.5).abs() < _snap ? 0.5 : _rawX;
              widget.onChanged(widget.config.copyWith(xPct: x, yPct: _rawY));
            },
            onPanEnd: (_) => setState(() => _dragging = false),
            onPanCancel: () => setState(() => _dragging = false),
            child: Container(
              foregroundDecoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.electricBlue.withValues(alpha: _dragging ? 0.9 : 0.45),
                  width: 1,
                ),
              ),
              child: CustomPaint(
                size: l.size,
                painter: _GuestTextPainter(l),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuestTextPainter extends CustomPainter {
  _GuestTextPainter(this.layout);

  final GuestTextLayout layout;

  @override
  void paint(Canvas canvas, Size size) => layout.paint(canvas, Offset.zero);

  @override
  bool shouldRepaint(covariant _GuestTextPainter old) => true;
}
