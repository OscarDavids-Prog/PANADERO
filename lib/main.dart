import 'package:flutter/material.dart';

import 'domain.dart';
import 'editor.dart';
import 'diary.dart';
import 'file_exchange.dart';
import 'storage.dart';
import 'ui_helpers.dart';
import 'preparations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PanaderoApp());
}

class PanaderoApp extends StatelessWidget {
  const PanaderoApp({super.key, this.store});
  final PanaderoStore? store;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Panadero',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B4F2B)),
          scaffoldBackgroundColor: const Color(0xFFFCF9F3),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          useMaterial3: true,
        ),
        home: _Boot(store: store),
      );
}

class _Boot extends StatefulWidget {
  const _Boot({this.store});
  final PanaderoStore? store;
  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  late Future<PanaderoStore> _opening;
  @override
  void initState() {
    super.initState();
    _opening = widget.store == null
        ? PanaderoStore.open()
        : Future.value(widget.store);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _opening,
        builder: (context, snapshot) {
          if (snapshot.hasData) return HomePage(store: snapshot.requireData);
          return Scaffold(
              body: Center(
                  child: snapshot.hasError
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                  'No se pudo abrir el almacén local. No se borraron datos.'),
                              SelectableText('${snapshot.error}'),
                              FilledButton(
                                  onPressed: () => setState(() {
                                        _opening = PanaderoStore.open();
                                      }),
                                  child: const Text('Reintentar')),
                            ],
                          ))
                      : const CircularProgressIndicator()));
        },
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});
  final PanaderoStore store;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  bool _busy = true;
  String? _loadError;
  String _recipeQuery = '';
  String _bakeQuery = '';
  List<Recipe> _recipes = [];
  List<Bake> _bakes = [];
  List<PreparedBatch> _prepared = [];
  final _exchange = FileExchange();
  late final Recipe _draft = Recipe(
      id: newId(),
      name: 'Mi receta',
      category: 'Otro',
      formula: const Formula());

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final recipes = await widget.store.recipes();
      final bakes = await widget.store.bakes();
      final prepared = await widget.store.preparedBatches();
      if (mounted) {
        setState(() {
          _recipes = recipes;
          _bakes = bakes;
          _prepared = prepared;
          _loadError = null;
          _busy = false;
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _loadError = '$error';
          _busy = false;
        });
      }
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Exception catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(Recipe recipe) async {
    await widget.store.saveRecipe(recipe);
    await _refresh();
    if (mounted) message(context, 'Receta guardada en el dispositivo.');
  }

  Future<void> _start(Recipe recipe) async {
    final bake = Bake(id: newId(), recipe: recipe, created: DateTime.now());
    await widget.store.saveBake(bake);
    await _refresh();
    if (!mounted) return;
    setState(() => _tab = 2);
    await _openBake(bake);
  }

  Future<void> _openBake(Bake bake) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BakePage(store: widget.store, initial: bake),
    ));
    await _refresh();
  }

  Future<void> _editRecipe(Recipe recipe, {bool copy = false}) async {
    final initial = copy ? recipe.withId(newId()) : recipe;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (routeContext) => Scaffold(
        appBar: AppBar(title: Text(copy ? 'Nueva copia' : 'Editar receta')),
        body: RecipeEditor(
          initial: initial,
          onSave: (r) async {
            await _save(r);
            if (routeContext.mounted) Navigator.pop(routeContext);
          },
          onStart: (r) async {
            final bake = Bake(id: newId(), recipe: r, created: DateTime.now());
            await widget.store.saveBake(bake);
            if (routeContext.mounted) Navigator.pop(routeContext);
            if (mounted) {
              setState(() => _tab = 2);
              await _openBake(bake);
            }
          },
        ),
      ),
    ));
    await _refresh();
  }

  Future<void> _import() async {
    final transfer = await _exchange.read();
    if (transfer == null || !mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vista previa de importación'),
        content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${transfer.recipes.length} recetas · ${transfer.bakes.length} amasadas · '
                    '${transfer.prepared.length} preparados'),
                const SizedBox(height: 12),
                ...transfer.recipes
                    .map((r) => Text('• ${r.name} (${r.category})')),
                ...transfer.bakes.map((b) =>
                    Text('• ${b.recipe.name} — ${displayDate(b.created)}')),
                ...transfer.prepared.map(
                    (p) => Text('• ${p.name} — ${displayDate(p.created)}')),
                const SizedBox(height: 12),
                const Text(
                    'Se agregarán como copias. No se reemplaza ni elimina ningún dato local. '
                    'Importar nuevamente el mismo archivo generará duplicados.'),
              ],
            ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importar copias')),
        ],
      ),
    );
    if (approved != true) return;
    await widget.store.importTransfer(transfer);
    await _refresh();
    if (mounted) message(context, 'Importación completada.');
  }

  Future<void> _export(Transfer transfer, {bool share = false}) async {
    final outcome = await _exchange.export(transfer, share: share);
    if (!mounted) return;
    switch (outcome) {
      case ExportOutcome.saved:
        message(context, 'Archivo guardado.');
      case ExportOutcome.handedOff:
        message(context,
            'Archivo entregado a la aplicación elegida. Verificá allí el envío.');
      case ExportOutcome.unconfirmed:
        message(context,
            'El sistema no confirmó el resultado. Verificá el archivo o el envío.');
      case ExportOutcome.dismissed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _recipes
        .where((r) => '${r.name} ${r.category}'
            .toLowerCase()
            .contains(_recipeQuery.toLowerCase()))
        .toList();
    final bakes = _bakes
        .where((b) =>
            '${b.recipe.name} ${b.recipe.category} ${b.notes} ${b.result}'
                .toLowerCase()
                .contains(_bakeQuery.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panadero'),
        actions: [
          PopupMenuButton<String>(
            enabled: !_busy && _loadError == null,
            tooltip: 'Archivos y respaldo',
            onSelected: (value) => _action(() async {
              if (value == 'import') {
                await _import();
              } else {
                await _export(Transfer(
                    recipes: _recipes,
                    bakes: value == 'backup' ? _bakes : [],
                    prepared: value == 'backup' ? _prepared : [],
                    backup: value == 'backup'));
              }
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('Importar archivo')),
              PopupMenuItem(
                  value: 'recipes', child: Text('Exportar todas las recetas')),
              PopupMenuItem(value: 'backup', child: Text('Respaldo completo')),
            ],
          ),
        ],
      ),
      body: _loadError != null
          ? Center(
              child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'No se pudo leer el almacén. No se sobrescribieron los datos.'),
                SelectableText(_loadError!),
                FilledButton(
                    onPressed: _refresh, child: const Text('Reintentar')),
              ]),
            ))
          : Column(children: [
              if (_busy) const LinearProgressIndicator(),
              Expanded(
                  child: IndexedStack(index: _tab, children: [
                RecipeEditor(initial: _draft, onSave: _save, onStart: _start),
                _library(recipes),
                _diary(bakes),
                PreparationsPage(
                    store: widget.store,
                    batches: _prepared,
                    onChanged: _refresh),
              ])),
            ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (v) => setState(() => _tab = v),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calculate_outlined), label: 'Calculadora'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), label: 'Recetas'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Amasadas'),
          NavigationDestination(
              icon: Icon(Icons.grain_outlined), label: 'Preparados'),
        ],
      ),
    );
  }

  Widget _search({required bool recipes}) => Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          key: ValueKey(recipes ? 'recipe-search' : 'bake-search'),
          decoration: const InputDecoration(
              labelText: 'Buscar por nombre o variedad',
              prefixIcon: Icon(Icons.search)),
          onChanged: (value) => setState(() {
            if (recipes) {
              _recipeQuery = value;
            } else {
              _bakeQuery = value;
            }
          }),
        ),
      );
  Widget _library(List<Recipe> recipes) => Column(children: [
        _search(recipes: true),
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: recipes.isEmpty ? 1 : recipes.length,
          itemBuilder: (context, index) {
            if (recipes.isEmpty) {
              return const ListTile(
                  title: Text('No hay recetas que coincidan.'));
            }
            final recipe = recipes[index];
            final result = recipe.formula.calculate();
            return Card(
                child: ListTile(
              isThreeLine: true,
              title: Text(recipe.name),
              subtitle: Text(
                  '${recipe.category}\n${grams(result.total)} g · ${grams(result.hydration)} % agua'),
              onTap: () => _editRecipe(recipe),
              trailing: PopupMenuButton<String>(
                tooltip: 'Acciones de receta',
                onSelected: (value) {
                  if (value == 'edit' || value == 'copy') {
                    _editRecipe(recipe, copy: value == 'copy');
                  } else {
                    _action(() async {
                      if (value == 'start') {
                        await _start(recipe);
                      } else if (value == 'delete') {
                        if (await confirmDelete(
                            context, 'la receta "${recipe.name}"')) {
                          await widget.store.deleteRecipe(recipe.id);
                          await _refresh();
                        }
                      } else {
                        await _export(
                            Transfer(
                                recipes: [recipe],
                                bakes: const [],
                                backup: false),
                            share: value == 'share');
                      }
                    });
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'start', child: Text('Iniciar amasada')),
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'copy', child: Text('Crear copia')),
                  PopupMenuItem(
                      value: 'share', child: Text('Compartir archivo')),
                  PopupMenuItem(
                      value: 'export', child: Text('Exportar archivo')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ));
          },
        )),
      ]);
  Widget _diary(List<Bake> bakes) => Column(children: [
        _search(recipes: false),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
                'Compará fórmulas y condiciones similares. Los tiempos registrados no son predicciones.')),
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bakes.isEmpty ? 1 : bakes.length,
          itemBuilder: (context, index) {
            if (bakes.isEmpty) {
              return const ListTile(
                  title: Text(
                      'Todavía no hay amasadas. Iniciá una desde una receta.'));
            }
            final bake = bakes[index];
            final result = bake.recipe.formula.calculate();
            return Card(
                child: ListTile(
              title: Text('${bake.recipe.name} · ${displayDate(bake.created)}'),
              subtitle: Text(
                '${grams(result.hydration)} % agua · MM ${grams(result.starterPercent)} % · '
                'harina prefermentada ${grams(result.prefermentedPercent)} %\n'
                '${yeastDescription(bake.recipe.formula)}\n'
                'MM: ${bake.starterState.isEmpty ? 'estado sin registrar' : bake.starterState}\n'
                '${stageSummary(bake)}\n'
                '${bake.result.isEmpty ? 'Sin evaluación' : bake.result}',
              ),
              onTap: () => _openBake(bake),
              trailing: IconButton(
                tooltip: 'Eliminar amasada',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _action(() async {
                  if (await confirmDelete(context, 'esta amasada')) {
                    await widget.store.deleteBake(bake.id);
                    await _refresh();
                  }
                }),
              ),
            ));
          },
        )),
      ]);
}
