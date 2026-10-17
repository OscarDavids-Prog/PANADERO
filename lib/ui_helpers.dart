import 'package:flutter/material.dart';
import 'domain.dart';

String yeastDescription(Formula f) => f.mode == CalculationMode.weights
    ? 'Levadura: ${grams(f.yeast)} g'
    : 'Levadura adicional: ${grams(f.yeast)} %'
        '${f.yeastSeed && f.preferment != Preferment.none && f.preferment != Preferment.starter ? ' + inóculo de levadura' : ''}';

String stageSummary(Bake bake) => bake.stages.isEmpty
    ? 'Sin etapas registradas'
    : bake.stages
        .map((s) =>
            '${s.name}: ${s.hours == null ? 'en curso' : '${grams(s.hours!)} h'}'
            '${s.ambient == null ? '' : ' · ambiente ${grams(s.ambient!)} °C'}'
            '${s.dough == null ? '' : ' · masa ${grams(s.dough!)} °C'}'
            '${s.fridge == null ? '' : ' · heladera ${grams(s.fridge!)} °C'}'
            '${s.growth == null ? '' : ' · crecimiento ${grams(s.growth!)} %'}')
        .join('\n');

String grams(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
String displayDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';
String dateTimeText(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';

DateTime parseLocalDateTime(String source) {
  final text = source.trim();
  final parsed = DateTime.tryParse(text);
  if (parsed == null || dateTimeText(parsed) != text) {
    throw const FormatException(
        'Usá una fecha y hora válida: AAAA-MM-DD HH:MM.');
  }
  return parsed;
}

void message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
void showError(BuildContext context, Object error) {
  debugPrint('Panadero: $error');
  message(context, 'No se pudo completar la operación: $error');
}

Future<bool> confirmDelete(BuildContext context, String subject) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Confirmar eliminación'),
              content: Text(
                  '¿Eliminar $subject? Esta acción no se puede deshacer. '
                  'Eliminar una receta no modifica las amasadas ya registradas.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Eliminar')),
              ],
            )) ??
    false;
