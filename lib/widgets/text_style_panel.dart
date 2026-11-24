import 'package:material_ui/material_ui.dart';

import '../models/text_style_config.dart';
import 'color_palette_row.dart';

/// Panel inferior con todos los controles de estilo del texto.
class TextStylePanel extends StatelessWidget {
  const TextStylePanel({
    super.key,
    required this.config,
    required this.sampleText,
    required this.onChanged,
    required this.onSampleTextChanged,
  });

  final TextStyleConfig config;
  final String sampleText;
  final ValueChanged<TextStyleConfig> onChanged;
  final ValueChanged<String> onSampleTextChanged;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      shrinkWrap: true,
      children: [
        TextFormField(
          initialValue: sampleText,
          decoration: const InputDecoration(
            labelText: 'Nombre de prueba',
            prefixIcon: Icon(Icons.person_outline),
            isDense: true,
          ),
          onChanged: onSampleTextChanged,
        ),
        const SizedBox(height: 12),
        _SliderRow(
          label: 'Tamaño de fuente',
          valueLabel: '${(config.fontSizePct * 100).toStringAsFixed(1)}%',
          value: config.fontSizePct,
          min: 0.02,
          max: 0.20,
          onChanged: (v) => onChanged(config.copyWith(fontSizePct: v)),
        ),
        _SliderRow(
          label: 'Grosor del contorno',
          valueLabel: '${(config.strokeWidthPct * 100).round()}%',
          value: config.strokeWidthPct,
          min: 0,
          max: 0.30,
          onChanged: (v) => onChanged(config.copyWith(strokeWidthPct: v)),
        ),
        const SizedBox(height: 4),
        ColorPaletteRow(
          label: 'Color del texto',
          selected: config.textColor,
          onChanged: (c) => onChanged(config.copyWith(textColor: c)),
        ),
        const SizedBox(height: 12),
        ColorPaletteRow(
          label: 'Color del contorno',
          selected: config.strokeColor,
          onChanged: (c) => onChanged(config.copyWith(strokeColor: c)),
        ),
        const SizedBox(height: 12),
        Text('Fuente', style: labelStyle),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kFontOptions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = kFontOptions[i];
              return ChoiceChip(
                selected: config.fontIndex == i,
                onSelected: (_) => onChanged(config.copyWith(fontIndex: i)),
                label: Text(
                  f.label,
                  style: TextStyle(
                    fontFamily: f.family,
                    fontWeight: f.weight,
                    fontStyle: f.italic ? FontStyle.italic : FontStyle.normal,
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => onChanged(config.copyWith(xPct: 0.5)),
          icon: const Icon(Icons.align_horizontal_center),
          label: const Text('Centrar horizontalmente'),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Posición: X ${(config.xPct * 100).toStringAsFixed(1)}%  ·  Y ${(config.yPct * 100).toStringAsFixed(1)}%',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white54),
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(valueLabel, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
