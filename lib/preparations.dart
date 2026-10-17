import 'package:flutter/material.dart';

import 'domain.dart';
import 'editor.dart' show parseNumber;
import 'storage.dart';
import 'ui_helpers.dart';

String buildKindName(StarterBuildKind kind) => switch (kind) {
      StarterBuildKind.refresh => 'Refresco de MM',
      StarterBuildKind.biga => 'Biga de MM',
      StarterBuildKind.poolish => 'Poolish de MM',
    };

class PreparedSummary extends StatelessWidget {
  const PreparedSummary({super.key, required this.batch});
  final PreparedBatch batch;
  @override
  Widget build(BuildContext context) {
    final result = batch.build.calculate();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          '${buildKindName(batch.build.kind)} · ${dateTimeText(batch.created)}'),
      Text('Pesar: ${grams(result.seed)} g de MM inicial '
          '(${grams(batch.build.seedHydration)} % hid.) + '
          '${grams(result.addedFlour)} g de harina + '
          '${grams(result.addedWater)} g de agua'),
      Text('Total: ${grams(result.total)} g · '
          'Hidratación final: ${grams(result.hydration)} %'),
      if (batch.notes.isNotEmpty) Text(batch.notes),
    ]);
  }
}

class PreparationsPage extends StatefulWidget {
  const PreparationsPage(
      {super.key,
      required this.store,
      required this.batches,
      required this.onChanged});
  final PanaderoStore store;
  final List<PreparedBatch> batches;
  final Future<void> Function() onChanged;
  @override
  State<PreparationsPage> createState() => _PreparationsPageState();
}

class _PreparationsPageState extends State<PreparationsPage> {
  String _query = '';
  bool _busy = false;
  Future<void> _edit([PreparedBatch? batch]) async {
    if (_busy) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PreparedEditor(store: widget.store, initial: batch),
    ));
    await widget.onChanged();
  }

  Future<void> _delete(PreparedBatch batch) async {
    if (_busy) return;
    if (!await confirmDelete(context, 'el preparado "${batch.name}"')) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await widget.store.deletePrepared(batch.id);
      await widget.onChanged();
    } on Exception catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batches = widget.batches
        .where((p) => '${p.name} ${buildKindName(p.build.kind)} ${p.notes}'
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                  'Refrescos y prefermentos con historial independiente. '
                  'Registrá la fecha real, los ingredientes y tus notas.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: _busy ? null : () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo preparado / refresco')),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                    labelText: 'Buscar preparados',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (value) => setState(() => _query = value),
              ),
            ],
          )),
      if (_busy) const LinearProgressIndicator(),
      Expanded(
          child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: batches.isEmpty ? 1 : batches.length,
        itemBuilder: (context, index) {
          if (batches.isEmpty) {
            return const ListTile(title: Text('Sin preparados que coincidan.'));
          }
          final batch = batches[index];
          return Card(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(batch.name, style: Theme.of(context).textTheme.titleMedium),
              PreparedSummary(batch: batch),
              Wrap(spacing: 8, children: [
                TextButton(
                    onPressed: _busy ? null : () => _edit(batch),
                    child: const Text('Editar preparado')),
                TextButton(
                    onPressed: _busy ? null : () => _delete(batch),
                    child: const Text('Eliminar preparado')),
              ]),
            ]),
          ));
        },
      )),
    ]);
  }
}

class PreparedEditor extends StatefulWidget {
  const PreparedEditor({super.key, required this.store, this.initial});
  final PanaderoStore store;
  final PreparedBatch? initial;
  @override
  State<PreparedEditor> createState() => _PreparedEditorState();
}

class _PreparedEditorState extends State<PreparedEditor> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  late StarterBuildKind _kind;
  late final String _id;
  bool _busy = false;
  StarterBuild? _valid;
  String? _error;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final build = initial?.build ?? const StarterBuild();
    _id = initial?.id ?? newId();
    _kind = build.kind;
    final values = {
      'name': initial?.name ?? buildKindName(_kind),
      'created': dateTimeText(initial?.created ?? DateTime.now()),
      'seedMass': '${build.seedMass}',
      'flourRatio': '${build.flourRatio}',
      'waterRatio': '${build.waterRatio}',
      'seedHydration': '${build.seedHydration}',
      'flour': '${build.flour}',
      'hydration': '${build.hydration}',
      'seedPercent': '${build.seedPercent}',
      'notes': initial?.notes ?? '',
    };
    values.forEach(
        (key, value) => _fields[key] = TextEditingController(text: value));
    _calculate();
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  double _number(String key) => parseNumber(_fields[key]!.text);
  void _calculate() {
    try {
      final refresh = _kind == StarterBuildKind.refresh;
      final build = StarterBuild(
        kind: _kind,
        seedHydration: _number('seedHydration'),
        seedMass: refresh ? _number('seedMass') : 20,
        flourRatio: refresh ? _number('flourRatio') : 2,
        waterRatio: refresh ? _number('waterRatio') : 2,
        flour: refresh ? 200 : _number('flour'),
        hydration: refresh ? 50 : _number('hydration'),
        seedPercent: refresh ? 10 : _number('seedPercent'),
      );
      build.calculate();
      _valid = build;
      _error = null;
    } on FormatException catch (error) {
      _valid = null;
      _error = error.message;
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _valid == null) return;
    setState(() => _busy = true);
    try {
      final batch = PreparedBatch(
        id: _id,
        name: _fields['name']!.text.trim(),
        created: parseLocalDateTime(_fields['created']!.text),
        build: _valid!,
        notes: _fields['notes']!.text.trim(),
      );
      await widget.store.savePrepared(batch);
      if (mounted) Navigator.pop(context);
    } on Exception catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, String label,
          {bool numeric = true, int lines = 1, String? helper}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          key: ValueKey('prepared-$key'),
          controller: _fields[key],
          maxLines: lines,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
              labelText: label, helperText: helper, helperMaxLines: 3),
          onChanged: numeric ? (_) => setState(_calculate) : null,
          validator: (value) {
            try {
              if (numeric) {
                parseNumber(value ?? '');
              } else if (key == 'created') {
                parseLocalDateTime(value ?? '');
              } else if (key == 'name' &&
                  (value == null || value.trim().isEmpty)) {
                return 'Ingresá un nombre.';
              }
              return null;
            } on FormatException catch (error) {
              return error.message;
            }
          },
        ),
      );
  @override
  Widget build(BuildContext context) {
    final result = _valid?.calculate();
    final refresh = _kind == StarterBuildKind.refresh;
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.initial == null ? 'Nuevo preparado' : 'Editar preparado')),
      body: AbsorbPointer(
          absorbing: _busy,
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    DropdownButtonFormField<StarterBuildKind>(
                      initialValue: _kind,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Tipo de preparado'),
                      items: StarterBuildKind.values
                          .map((kind) => DropdownMenuItem(
                              value: kind, child: Text(buildKindName(kind))))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          if (_fields['name']!.text == buildKindName(_kind)) {
                            _fields['name']!.text = buildKindName(value);
                          }
                          _kind = value;
                          _fields['hydration']!.text =
                              value == StarterBuildKind.poolish ? '100' : '50';
                          _calculate();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _field('name', 'Nombre', numeric: false),
                    _field('created', 'Fecha y hora local · AAAA-MM-DD HH:MM',
                        numeric: false),
                    _field('seedHydration', 'Hidratación de la MM inicial (%)',
                        helper: result == null
                            ? null
                            : 'La MM inicial aporta '
                                '${grams(result.seed / (1 + _valid!.seedHydration / 100))} g de harina '
                                'y ${grams(result.seed - result.seed / (1 + _valid!.seedHydration / 100))} g de agua.'),
                    if (refresh) ...[
                      const Text(
                          'Proporción MM inicial : harina nueva : agua nueva. '
                          'La MM es 1 parte. Ejemplo 1:2:2: por 20 g de MM, agregar '
                          '40 g de harina y 40 g de agua.'),
                      const SizedBox(height: 16),
                      _field('seedMass', 'MM inicial (g)'),
                      _field('flourRatio', 'Partes de harina nueva por 1 de MM',
                          helper: result == null
                              ? null
                              : '${grams(result.addedFlour)} g de harina a pesar'),
                      _field('waterRatio', 'Partes de agua nueva por 1 de MM',
                          helper: result == null
                              ? null
                              : '${grams(result.addedWater)} g de agua a pesar'),
                    ] else ...[
                      const Text(
                          'La harina y el agua totales incluyen el aporte de la MM. '
                          'No agregues el inóculo por fuera de esas cantidades.'),
                      const SizedBox(height: 16),
                      _field('flour', 'Harina total del prefermento (g)'),
                      _field('hydration', 'Hidratación objetivo (%)',
                          helper: result == null
                              ? null
                              : '${grams(result.totalWater)} g de agua total · '
                                  '${grams(result.addedWater)} g a agregar'),
                      _field('seedPercent',
                          'Peso de MM / harina total del prefermento (%)',
                          helper: result == null
                              ? null
                              : '${grams(result.seed)} g de MM a pesar'),
                    ],
                    _field('notes', 'Notas del refresco o preparación',
                        numeric: false, lines: 3),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    if (result != null)
                      Card(
                          child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Balanza del preparado',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              Text('MM inicial: ${grams(result.seed)} g'),
                              Text(
                                  'Harina nueva: ${grams(result.addedFlour)} g'),
                              Text('Agua nueva: ${grams(result.addedWater)} g'),
                              Text('Total preparado: ${grams(result.total)} g'),
                              Text(
                                  'Hidratación final: ${grams(result.hydration)} %'),
                            ]),
                      )),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        onPressed: _busy || _valid == null ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar preparado')),
                    if (_busy) const LinearProgressIndicator(),
                  ],
                )),
          ))),
    );
  }
}
