import 'package:flutter/material.dart';

import 'domain.dart';
import 'editor.dart';
import 'ui_helpers.dart';
import 'storage.dart';
import 'preparations.dart';

class BakePage extends StatefulWidget {
  const BakePage({super.key, required this.store, required this.initial});
  final PanaderoStore store;
  final Bake initial;
  @override
  State<BakePage> createState() => _BakePageState();
}

class _BakePageState extends State<BakePage> {
  late Bake _bake;
  late final TextEditingController _state, _notes, _result;
  bool _busy = false;
  bool _dirty = false;
  @override
  void initState() {
    super.initState();
    _bake = widget.initial;
    _state = TextEditingController(text: _bake.starterState);
    _notes = TextEditingController(text: _bake.notes);
    _result = TextEditingController(text: _bake.result);
    for (final field in [_state, _notes, _result]) {
      field.addListener(() {
        if (mounted) setState(() => _dirty = true);
      });
    }
  }

  @override
  void dispose() {
    _state.dispose();
    _notes.dispose();
    _result.dispose();
    super.dispose();
  }

  Future<bool> _save({List<FermentationStage>? stages}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      final bake = _bake.copy(
          stages: stages,
          starterState: _state.text,
          notes: _notes.text,
          result: _result.text);
      await widget.store.saveBake(bake);
      if (mounted) {
        setState(() {
          _bake = bake;
          _dirty = false;
        });
      }
      return true;
    } on Exception catch (error) {
      if (mounted) showError(context, error);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkPrepared() async {
    if (_busy) return;
    try {
      final batches = await widget.store.preparedBatches();
      if (!mounted) return;
      if (batches.isEmpty) {
        message(
            context, 'Primero guardá un refresco o prefermento en Preparados.');
        return;
      }
      final chosen = await showDialog<PreparedBatch>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Elegir preparado utilizado'),
          children: [
            for (final batch in batches)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, batch),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(batch.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      PreparedSummary(batch: batch),
                    ]),
              ),
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
          ],
        ),
      );
      if (chosen == null || !mounted) return;
      await _savePreparedLink(chosen);
    } on Exception catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _savePreparedLink(PreparedBatch? prepared) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bake = _bake.copy(
        prepared: prepared,
        clearPrepared: prepared == null,
        starterState: _state.text,
        notes: _notes.text,
        result: _result.text,
      );
      await widget.store.saveBake(bake);
      if (mounted) {
        setState(() {
          _bake = bake;
          _dirty = false;
        });
      }
    } on Exception catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stage([int? index]) async {
    final stage = await showDialog<FermentationStage>(
      context: context,
      builder: (_) =>
          _StageDialog(initial: index == null ? null : _bake.stages[index]),
    );
    if (stage == null || !mounted) return;
    final stages = [..._bake.stages];
    if (index == null) {
      stages.add(stage);
    } else {
      stages[index] = stage;
    }
    stages.sort((a, b) => a.start.compareTo(b.start));
    await _save(stages: stages);
  }

  Future<void> _back() async {
    if (_busy) return;
    if (_dirty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambios sin guardar'),
          content: const Text(
              'Guardá las notas antes de salir o descartá los cambios.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Seguir editando')),
            TextButton(
                onPressed: () => Navigator.pop(context, 'discard'),
                child: const Text('Descartar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, 'save'),
                child: const Text('Guardar y salir')),
          ],
        ),
      );
      if (choice == null || (choice == 'save' && !await _save())) return;
    }
    if (mounted) {
      setState(() => _dirty = false);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_dirty && !_busy,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Scaffold(
          appBar: AppBar(
              title: Text(_bake.recipe.name),
              leading: BackButton(onPressed: _back)),
          body: AbsorbPointer(
              absorbing: _busy,
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Text('Amasada: ${dateTimeText(_bake.created)}'),
                  const Text(
                      'La fórmula es una copia fija: editar o borrar la receta no cambia esta amasada.'),
                  ExpansionTile(
                    title: const Text('Fórmula utilizada e instrucciones'),
                    children: [
                      CalculationView(formula: _bake.recipe.formula),
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_bake.recipe.instructions)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                      child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Preparado utilizado',
                              style: Theme.of(context).textTheme.titleMedium),
                          const Text(
                              'Enlace documental: no cambia la fórmula ni descuenta existencias. '
                              'Se conserva una copia aunque después edites o elimines el preparado.'),
                          if (_bake.prepared != null) ...[
                            const SizedBox(height: 8),
                            Text(_bake.prepared!.name),
                            PreparedSummary(batch: _bake.prepared!),
                          ],
                          Wrap(spacing: 8, children: [
                            TextButton(
                                onPressed: _linkPrepared,
                                child: Text(_bake.prepared == null
                                    ? 'Vincular preparado'
                                    : 'Cambiar preparado')),
                            if (_bake.prepared != null)
                              TextButton(
                                  onPressed: () => _savePreparedLink(null),
                                  child: const Text('Quitar vínculo')),
                          ]),
                        ]),
                  )),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _state,
                      decoration: const InputDecoration(
                          labelText:
                              'Estado de la MM (pico, creciendo, pasada…)')),
                  const SizedBox(height: 16),
                  Text('Etapas de desarrollo y fermentación',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Text(
                      'Registrá inicio y fin reales. Podés cargar horarios anteriores. '
                      'Las etapas pueden superponerse: por ejemplo, pliegues dentro del bloque.'),
                  const SizedBox(height: 8),
                  if (_bake.stages.isEmpty) const Text('Sin etapas todavía.'),
                  ..._bake.stages.indexed.map((entry) {
                    final (index, stage) = entry;
                    return Card(
                        child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stage.name,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                '${dateTimeText(stage.start)} → ${stage.end == null ? 'En curso' : dateTimeText(stage.end!)}'),
                            if (stage.hours != null)
                              Text('Duración: ${grams(stage.hours!)} h'),
                            Text([
                              if (stage.ambient != null)
                                'Ambiente: ${stage.ambient} °C',
                              if (stage.dough != null)
                                'Masa: ${stage.dough} °C',
                              if (stage.fridge != null)
                                'Heladera: ${stage.fridge} °C',
                              if (stage.growth != null)
                                'Crecimiento: ${stage.growth} %',
                            ].join(' · ')),
                            if (stage.notes.isNotEmpty) Text(stage.notes),
                            Wrap(spacing: 8, children: [
                              TextButton(
                                  onPressed: () => _stage(index),
                                  child: const Text('Editar etapa')),
                              if (stage.end == null)
                                TextButton(
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    if (now.isBefore(stage.start)) {
                                      showError(
                                          context,
                                          const FormatException(
                                              'La etapa todavía no comenzó.'));
                                      return;
                                    }
                                    final stages = [..._bake.stages];
                                    stages[index] = FermentationStage(
                                      name: stage.name,
                                      start: stage.start,
                                      end: now,
                                      ambient: stage.ambient,
                                      dough: stage.dough,
                                      fridge: stage.fridge,
                                      growth: stage.growth,
                                      notes: stage.notes,
                                    );
                                    await _save(stages: stages);
                                  },
                                  child: const Text('Finalizar ahora'),
                                ),
                              TextButton(
                                  onPressed: () async {
                                    final approved = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title:
                                            const Text('¿Eliminar esta etapa?'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancelar')),
                                          FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Eliminar')),
                                        ],
                                      ),
                                    );
                                    if (approved == true) {
                                      final stages = [..._bake.stages]
                                        ..removeAt(index);
                                      await _save(stages: stages);
                                    }
                                  },
                                  child: const Text('Eliminar etapa')),
                            ]),
                          ]),
                    ));
                  }),
                  OutlinedButton.icon(
                      onPressed: () => _stage(),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar etapa / iniciar ahora')),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText:
                              'Notas: pliegues, harina, observaciones…')),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _result,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText:
                              'Resultado: miga, acidez, volumen, evaluación')),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: () async {
                        if (await _save() && context.mounted) {
                          message(context, 'Amasada guardada.');
                        }
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar notas y resultado')),
                  if (_busy) const LinearProgressIndicator(),
                  const SizedBox(height: 24),
                ]),
              ))),
        ),
      );
}

class _StageDialog extends StatefulWidget {
  const _StageDialog({this.initial});
  final FermentationStage? initial;
  @override
  State<_StageDialog> createState() => _StageDialogState();
}

class _StageDialogState extends State<_StageDialog> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  String? _error;
  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    final values = {
      'name': s?.name ?? 'Bloque',
      'start': dateTimeText(s?.start ?? DateTime.now()),
      'end': s?.end == null ? '' : dateTimeText(s!.end!),
      'ambient': s?.ambient?.toString() ?? '',
      'dough': s?.dough?.toString() ?? '',
      'fridge': s?.fridge?.toString() ?? '',
      'growth': s?.growth?.toString() ?? '',
      'notes': s?.notes ?? '',
    };
    values.forEach((k, v) => _fields[k] = TextEditingController(text: v));
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime _date(String key) {
    return parseLocalDateTime(_fields[key]!.text);
  }

  double? _temperature(String key) {
    final text = _fields[key]!.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null || !value.isFinite) {
      throw const FormatException('La temperatura debe ser un número.');
    }
    return value;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    try {
      final start = _date('start');
      final end = _fields['end']!.text.trim().isEmpty ? null : _date('end');
      if (end != null && end.isBefore(start)) {
        throw const FormatException('El fin no puede ser anterior al inicio.');
      }
      final stage = FermentationStage(
        name: _fields['name']!.text.trim(),
        start: start,
        end: end,
        ambient: _temperature('ambient'),
        dough: _temperature('dough'),
        fridge: _temperature('fridge'),
        growth: _fields['growth']!.text.trim().isEmpty
            ? null
            : parseNumber(_fields['growth']!.text),
        notes: _fields['notes']!.text,
      );
      Navigator.pop(context, stage);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Widget _field(String key, String label,
          {bool numeric = false, int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _fields[key],
            maxLines: lines,
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(
                    decimal: true, signed: true)
                : TextInputType.text,
            decoration: InputDecoration(labelText: label),
            validator: key == 'name'
                ? (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresá el nombre.' : null
                : null,
          ));
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'Nueva etapa' : 'Editar etapa'),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: Form(
              key: _form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Wrap(
                    spacing: 4,
                    children: [
                      'Autólisis',
                      'Bloque',
                      'Pliegues',
                      'Frío en bloque',
                      'Frío formado',
                      'Fermentación final',
                      'Horneado'
                    ]
                        .map((name) => ActionChip(
                            label: Text(name),
                            onPressed: () => _fields['name']!.text = name))
                        .toList()),
                const SizedBox(height: 14),
                _field('name', 'Etapa'),
                const Text('Horario local · AAAA-MM-DD HH:MM'),
                const SizedBox(height: 12),
                _field('start', 'Inicio'),
                _field('end', 'Fin (vacío si sigue en curso)'),
                TextButton(
                    onPressed: () =>
                        _fields['end']!.text = dateTimeText(DateTime.now()),
                    child: const Text('Usar hora actual como fin')),
                _field('ambient', 'Temperatura ambiente °C (opcional)',
                    numeric: true),
                _field('dough', 'Temperatura de masa °C (opcional)',
                    numeric: true),
                _field('fridge', 'Temperatura de heladera °C (opcional)',
                    numeric: true),
                _field('growth', 'Crecimiento observado % (opcional)',
                    numeric: true),
                _field('notes', 'Notas de esta etapa', lines: 2),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ]),
            ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('Guardar etapa')),
        ],
      );
}
