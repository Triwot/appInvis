import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

const List<Color> kPalette = [
  Color(0xFFFFFFFF),
  Color(0xFF000000),
  Color(0xFFFFD600),
  Color(0xFFFF9100),
  Color(0xFFFF1744),
  Color(0xFFF50057),
  Color(0xFFD500F9),
  Color(0xFF651FFF),
  Color(0xFF2979FF),
  Color(0xFF00B0FF),
  Color(0xFF00E5FF),
  Color(0xFF00E676),
  Color(0xFFC0C0C0),
  Color(0xFFD4AF37),
];

/// Fila horizontal de muestras de color.
class ColorPaletteRow extends StatelessWidget {
  const ColorPaletteRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kPalette.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = kPalette[i];
              final isSel = c.toARGB32() == selected.toARGB32();
              return GestureDetector(
                onTap: () => onChanged(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? AppTheme.electricBlue : AppTheme.outline,
                      width: isSel ? 3 : 1.5,
                    ),
                  ),
                  child: isSel
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: c.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
