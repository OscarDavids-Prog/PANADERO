import 'package:flutter/material.dart';

import 'domain.dart';
import 'ui_helpers.dart';

class RecipeEditor extends StatefulWidget {
  const RecipeEditor(
      {super.key,
      required this.initial,
      required this.onSave,
      required this.onStart});
  final Recipe initial;
  final Future<void> Function(Recipe) onSave, onStart;
  @override
  State<RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<RecipeEditor> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  final List<_ExtraInput> _extras = [];
  late CalculationMode _mode;
  late Preferment _pre;
  late Scald _scald;
  late bool _grams, _discount, _yeastSeed;
  bool _working = false;
  Formula? _valid;
  String? _error;
  final _categories = [
    'Rústico',
    'Lactal / Molde',
    'Prepizza',
    'Pizza / Rústico',
    'Flautas / Baguettes',
    'Focaccia',
    'Otro'
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    final f = r.formula;
    _mode = f.mode;
    _pre = f.preferment;
    _scald = f.scald;
    _grams = f.starterInGrams;
    _discount = f.discount;
    _yeastSeed = f.yeastSeed;
    final initial = <String, String>{
      'name': r.name,
      'category': r.category,
      'instructions': r.instructions,
      'base': '${f.base}',
      'water': '${f.water}',
      'salt': '${f.salt}',
      'yeast': '${f.yeast}',
      'starter': '${f.starter}',
      'preHyd': '${f.prefermentHydration}',
      'seedHyd': '${f.seedHydration}',
      'seed': '${f.seedPercent}',
      'scaldPct': '${f.scaldPercent}',
      'ratio': '${f.scaldRatio}',
      'pieces': '${f.pieces}',
    };
    initial.forEach(
        (key, value) => _fields[key] = TextEditingController(text: value));
    _extras.addAll(f.extras.map((e) => _ExtraInput(e.name, '${e.amount}')));
    _recalculate();
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    for (final extra in _extras) {
      extra.dispose();
    }
    super.dispose();
  }

  double _number(String key) => parseNumber(_fields[key]!.text);
  Formula _read() {
    final pieces = _number('pieces');
    if (pieces < 1 || pieces != pieces.roundToDouble()) {
      throw const FormatException(
          'La cantidad de piezas debe ser entera y positiva.');
    }
    return Formula(
      mode: _mode,
      base: _number('base'),
      water: _number('water'),
      salt: _number('salt'),
      yeast: _number('yeast'),
      preferment: _pre,
      starterInGrams: _grams,
      starter: _number('starter'),
      prefermentHydration: _number('preHyd'),
      seedHydration: _number('seedHyd'),
      seedPercent: _number('seed'),
      yeastSeed: _yeastSeed,
      scald: _scald,
      scaldPercent: _number('scaldPct'),
      scaldRatio: _number('ratio'),
      discount: _discount,
      pieces: pieces.toInt(),
      extras: _extras
          .map((e) =>
              ExtraIngredient(e.name.text.trim(), parseNumber(e.amount.text)))
          .toList(),
    );
  }

  void _recalculate() {
    try {
      final f = _read();
      f.calculate();
      _valid = f;
      _error = null;
    } on FormatException catch (error) {
      _valid = null;
      _error = error.message;
    }
  }

  void _change(VoidCallback action) => setState(() {
        action();
        _recalculate();
      });
  Future<void> _submit(bool start) async {
    if (!_form.currentState!.validate()) return;
    _recalculate();
    if (_valid == null) {
      setState(() {});
      return;
    }
    setState(() => _working = true);
    try {
      final recipe = Recipe(
          id: widget.initial.id,
          name: _fields['name']!.text.trim(),
          category: _fields['category']!.text.trim(),
          formula: _valid!,
          instructions: _fields['instructions']!.text.trim());
      await (start ? widget.onStart(recipe) : widget.onSave(recipe));
    } on Exception catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _text(String key, String label,
          {int lines = 1, bool required = false}) =>
      TextFormField(
        controller: _fields[key],
        maxLines: lines,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) =>
                v == null || v.trim().isEmpty ? 'Completá este campo.' : null
            : null,
      );
  Widget _numeric(String key, String label) => TextFormField(
        key: ValueKey('input-$key'),
        controller: _fields[key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          helperText: _equivalent(key),
          helperMaxLines: 3,
        ),
        onChanged: (_) => _change(() {}),
        validator: (value) {
          try {
            parseNumber(value ?? '');
            return null;
          } on FormatException catch (error) {
            return error.message;
          }
        },
      );

  String? _equivalent(String key) {
    if (key == 'pieces') return null;
    final f = _valid;
    if (f == null) return 'Equivalencia no disponible: revisá los valores.';
    final c = f.calculate();
    switch (key) {
      case 'base':
        return '${grams(c.baseFlour)} g de harina base · '
            '${grams(c.main.first.amount)} g de harina a agregar';
      case 'water':
        if (f.mode == CalculationMode.weights) {
          return _amountEquivalent(f.water);
        }
        return '${grams(c.baseFlour * f.water / 100)} g de agua '
            '${f.discount ? 'total objetivo' : 'base'} · '
            '${grams(c.main.firstWhere((e) => e.name == 'Agua').amount)} g a agregar';
      case 'salt':
        return _amountEquivalent(f.salt);
      case 'yeast':
        return _amountEquivalent(f.yeast);
      case 'starter':
        if (f.preferment != Preferment.starter) {
          return '${grams(c.prefermentedFlour)} g de harina destinada al prefermento';
        }
        return f.starterInGrams
            ? '${grams(c.starterMass / c.baseFlour * 100)} % del peso de harina base'
            : '${grams(c.starterMass)} g de MM a pesar';
      case 'preHyd':
        return '${grams(c.prefermentedFlour)} g de harina + '
            '${grams(c.prefermentedFlour * f.prefermentHydration / 100)} g de agua '
            'en el prefermento';
      case 'seed':
        return '${grams(c.previous.first.ingredients.last.amount)} g de '
            '${f.yeastSeed ? 'levadura' : 'MM'} de inóculo a pesar';
      case 'seedHyd':
        final seed = c.previous.first.ingredients.last.amount;
        final flour = seed / (1 + f.seedHydration / 100);
        return 'El inóculo aporta ${grams(flour)} g de harina + '
            '${grams(seed - flour)} g de agua';
      case 'scaldPct':
      case 'ratio':
        final prep = c.previous.last;
        return '${grams(prep.ingredients.first.amount)} g de harina + '
            '${grams(prep.ingredients.last.amount)} g de agua para precocción';
    }
    return null;
  }

  String _amountEquivalent(double amount) {
    final f = _valid;
    if (f == null) return 'Equivalencia no disponible: revisá los valores.';
    final flour = f.calculate().baseFlour;
    return f.mode == CalculationMode.weights
        ? '${grams(amount / flour * 100)} % del peso de harina base'
        : '${grams(flour * amount / 100)} g a pesar';
  }

  Widget _select<T>(String label, T value, Map<T, String> values,
          ValueChanged<T> changed) =>
      DropdownButtonFormField<T>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: values.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) {
          if (v != null) _change(() => changed(v));
        },
      );
  Widget _group(String title, List<Widget> children) => Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ...children.expand((child) => [child, const SizedBox(height: 14)]),
        ]),
      ));
  Widget _pair(Widget a, Widget b) => LayoutBuilder(
      builder: (context, c) => c.maxWidth < 470
          ? Column(children: [a, const SizedBox(height: 14), b])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: a),
              const SizedBox(width: 14),
              Expanded(child: b),
            ]));

  @override
  Widget build(BuildContext context) {
    final weights = _mode == CalculationMode.weights;
    final unit = weights ? 'g' : '%';
    return AbsorbPointer(
        absorbing: _working,
        child: Form(
          key: _form,
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text('Tu fórmula panadera',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Sin conexión. Los porcentajes se basan en harina. '
                  'El cálculo de hidratación cuenta agua y la contenida en las preparaciones; '
                  'no estima la humedad de leche, miel u otros ingredientes.'),
              const SizedBox(height: 12),
              _group('Receta', [
                _text('name', 'Nombre de la receta', required: true),
                _text('category', 'Variedad', required: true),
                Wrap(
                    spacing: 6,
                    children: _categories
                        .map((c) => ActionChip(
                              label: Text(c),
                              onPressed: () => _fields['category']!.text = c,
                            ))
                        .toList()),
              ]),
              _group('Base y cantidades', [
                _select('Calcular desde', _mode, const {
                  CalculationMode.flour: 'Harina de la fórmula',
                  CalculationMode.dough: 'Peso final de masa',
                  CalculationMode.weights:
                      'Pesos → porcentajes (sin premezclas)',
                }, (v) {
                  _mode = v;
                  _fields['base']!.text =
                      v == CalculationMode.dough ? '2000' : '500';
                  _fields['water']!.text =
                      v == CalculationMode.weights ? '350' : '70';
                  _fields['salt']!.text =
                      v == CalculationMode.weights ? '10' : '2';
                  _fields['yeast']!.text = '0';
                  for (final e in _extras) {
                    e.dispose();
                  }
                  _extras.clear();
                }),
                const Text(
                    'Cambiar de modo reinicia las cantidades y los adicionales; '
                    'guardá antes si querés conservarlos.'),
                _pair(
                    _numeric(
                        'base',
                        _mode == CalculationMode.dough
                            ? 'Masa final deseada (g)'
                            : 'Harina (g)'),
                    _numeric('water',
                        weights ? 'Agua (g)' : 'Hidratación objetivo (%)')),
                _pair(_numeric('salt', 'Sal ($unit)'),
                    _numeric('yeast', 'Levadura adicional ($unit)')),
                const Text('Indicá el tipo de levadura en las instrucciones. '
                    'La app no convierte automáticamente entre fresca y seca.'),
                if (!weights)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                        'Descontar harina y agua de las preparaciones'),
                    subtitle: Text(_discount
                        ? 'La harina indicada es la total de la fórmula.'
                        : 'La harina y el agua base se agregan completas, además de las preparaciones.'),
                    value: _discount,
                    onChanged: (v) => _change(() => _discount = v),
                  ),
              ]),
              if (!weights)
                _group('Prefermento', [
                  _select('Preparación', _pre, const {
                    Preferment.none: 'Sin prefermento',
                    Preferment.starter: 'Masa madre directa',
                    Preferment.poolish: 'Poolish',
                    Preferment.biga: 'Biga',
                  }, (v) {
                    _pre = v;
                    _fields['preHyd']!.text =
                        v == Preferment.biga ? '50' : '100';
                  }),
                  if (_pre != Preferment.none) ...[
                    if (_pre == Preferment.starter)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ingresar MM en gramos'),
                        subtitle: const Text(
                            'Si está desactivado: peso de MM / harina base × 100. '
                            'Cambiar la unidad conserva el número: revisalo.'),
                        value: _grams,
                        onChanged: (v) => _change(() => _grams = v),
                      ),
                    _pair(
                      _numeric(
                          'starter',
                          _pre != Preferment.starter
                              ? 'Harina destinada al prefermento (%)'
                              : _grams
                                  ? 'MM disponible (g)'
                                  : 'Peso de MM sobre harina base (%)'),
                      _numeric('preHyd', 'Hidratación del prefermento (%)'),
                    ),
                    if (_pre != Preferment.starter) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title:
                            const Text('Inocular con levadura en lugar de MM'),
                        value: _yeastSeed,
                        onChanged: (v) => _change(() => _yeastSeed = v),
                      ),
                      _numeric(
                          'seed',
                          _yeastSeed
                              ? 'Levadura / harina del prefermento (%)'
                              : 'Peso de MM / harina del prefermento (%)'),
                      if (!_yeastSeed)
                        _numeric(
                            'seedHyd', 'Hidratación de la MM de inóculo (%)'),
                      const Text(
                          'El inóculo de MM está incluido en la harina y el agua del prefermento. '
                          'La levadura de inóculo se suma al peso, además de la levadura del amasado.'),
                    ],
                  ],
                ]),
              if (!weights)
                _group('Precocción opcional', [
                  _select('Técnica', _scald, const {
                    Scald.none: 'Ninguna',
                    Scald.tangzhong: 'Tangzhong',
                    Scald.yudane: 'Yudane',
                  }, (v) {
                    _scald = v;
                    _fields['ratio']!.text = v == Scald.tangzhong ? '5' : '1';
                  }),
                  if (_scald != Scald.none)
                    _pair(
                      _numeric('scaldPct', 'Harina destinada a precocción (%)'),
                      _numeric('ratio', 'Agua por 1 g de harina (g)'),
                    ),
                ]),
              _group('Ingredientes adicionales', [
                const Text(
                    'Elegí nombres concretos: aceite, manteca, azúcar, miel… '
                    'Podés ingresar porcentajes y ver los gramos a pesar, '
                    'o usar el modo pesos para ingresar gramos y ver su porcentaje.'),
                ..._extras.map((e) => Column(children: [
                      _pair(
                        TextFormField(
                            controller: e.name,
                            decoration:
                                const InputDecoration(labelText: 'Ingrediente'),
                            onChanged: (_) => _change(() {})),
                        TextFormField(
                            controller: e.amount,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Cantidad ($unit)',
                              helperText: _valid == null
                                  ? 'Equivalencia no disponible: revisá los valores.'
                                  : _amountEquivalent(
                                      parseNumber(e.amount.text)),
                              helperMaxLines: 2,
                            ),
                            onChanged: (_) => _change(() {})),
                      ),
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _change(() {
                              _extras.remove(e);
                              e.dispose();
                            }),
                            icon: const Icon(Icons.close),
                            label: const Text('Quitar ingrediente'),
                          )),
                    ])),
                OutlinedButton.icon(
                    onPressed: () => _change(() {
                          _extras.add(_ExtraInput('', '0'));
                        }),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar ingrediente')),
              ]),
              _group('División y elaboración', [
                _numeric('pieces', 'Cantidad de piezas iguales'),
                _text('instructions',
                    'Instrucciones y cubierta (fuera del pastón)',
                    lines: 4),
              ]),
              if (_error != null)
                Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!,
                            key: const Key('calculation-error')))),
              if (_valid != null) CalculationView(formula: _valid!),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                FilledButton.icon(
                    onPressed: _valid == null || _working
                        ? null
                        : () => _submit(false),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar receta')),
                OutlinedButton.icon(
                    onPressed:
                        _valid == null || _working ? null : () => _submit(true),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar amasada')),
              ]),
              if (_working) const LinearProgressIndicator(),
              const SizedBox(height: 24),
            ]),
          )),
        ));
  }
}

class CalculationView extends StatelessWidget {
  const CalculationView({super.key, required this.formula});
  final Formula formula;
  @override
  Widget build(BuildContext context) {
    final result = formula.calculate();
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );
    List<Widget> amounts(List<ExtraIngredient> items) => items
        .where((e) => e.amount != 0 || e.name == 'Agua' || e.name == 'Harina')
        .map((e) => row(
            e.name,
            '${grams(e.amount)} g'
            '${formula.mode == CalculationMode.weights ? ' · ${grams(e.amount / result.flour * 100)} %' : ''}'))
        .toList();
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Balanza', style: Theme.of(context).textTheme.titleLarge),
        for (final prep in result.previous) ...[
          const SizedBox(height: 12),
          Text(prep.name, style: Theme.of(context).textTheme.titleMedium),
          ...amounts(prep.ingredients),
        ],
        const SizedBox(height: 12),
        Text('Amasado final', style: Theme.of(context).textTheme.titleMedium),
        ...amounts(result.main),
        const Divider(),
        row('Harina total', '${grams(result.flour)} g'),
        row('Agua total', '${grams(result.totalWater)} g'),
        row('Hidratación real (agua)', '${grams(result.hydration)} %'),
        row('Peso de MM / harina total', '${grams(result.starterPercent)} %'),
        row('Harina prefermentada / harina total',
            '${grams(result.prefermentedPercent)} %'),
        row('Peso total de masa', '${grams(result.total)} g'),
        row('${formula.pieces} piezas iguales',
            '${grams(result.total / formula.pieces)} g por pieza'),
        const SizedBox(height: 8),
        Text(yeastDescription(formula)),
        const Text('Pesos mostrados a 0,01 g; el cálculo interno no redondea. '
            'La balanza y las pérdidas de cocción pueden cambiar el peso real.'),
      ]),
    ));
  }
}

double parseNumber(String source) {
  final value = double.tryParse(source.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value < 0) {
    throw const FormatException(
        'Ingresá un número no negativo (admite coma decimal).');
  }
  return value;
}

class _ExtraInput {
  _ExtraInput(String name, String amount)
      : name = TextEditingController(text: name),
        amount = TextEditingController(text: amount);
  final TextEditingController name, amount;
  void dispose() {
    name.dispose();
    amount.dispose();
  }
}
