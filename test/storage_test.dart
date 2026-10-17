import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panadero/domain.dart';
import 'package:panadero/storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late PanaderoStore store;
  setUp(() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            version: PanaderoStore.schemaVersion,
            onCreate: PanaderoStore.createSchema));
    store = PanaderoStore(db);
  });
  tearDown(() => store.db.close());

  test('inicializa ejemplos y conserva instantánea al editar o eliminar receta',
      () async {
    final recipes = await store.recipes();
    expect(recipes.length, 3);
    final original = recipes.first;
    final bake = Bake(id: 'test', recipe: original, created: DateTime.now());
    await store.saveBake(bake);
    await store.saveRecipe(Recipe(
        id: original.id,
        name: 'Modificada',
        category: 'Otro',
        formula: const Formula(base: 100)));
    await store.deleteRecipe(original.id);
    final saved = (await store.bakes()).single;
    expect(saved.recipe.toJson(), original.toJson());
    expect((await store.recipes()).length, 2);
    await store.deleteBake(saved.id);
    expect(await store.bakes(), isEmpty);
  });
  test('importar es aditivo, incluso con IDs repetidos', () async {
    final recipes = await store.recipes();
    final bake =
        Bake(id: 'same', recipe: recipes.first, created: DateTime.now());
    final data =
        Transfer(recipes: [recipes.first], bakes: [bake], backup: true);
    await store.importTransfer(data);
    await store.importTransfer(data);
    final importedRecipes = await store.recipes();
    final importedBakes = await store.bakes();
    expect(importedRecipes.length, 5);
    expect(importedRecipes.map((r) => r.id).toSet().length, 5);
    expect(importedBakes.length, 2);
    expect(importedBakes.map((b) => b.id).toSet().length, 2);
  });
  test('guarda etapas y evaluación sin cambiar la fecha original', () async {
    final bake = Bake(
        id: 'test',
        recipe: (await store.recipes()).first,
        created: DateTime(2026, 10, 16));
    await store.saveBake(bake.copy(result: 'Bien', stages: [
      FermentationStage(
          name: 'Bloque',
          start: DateTime(2026, 10, 16, 20),
          end: DateTime(2026, 10, 17, 1),
          ambient: 23),
    ]));
    final saved = (await store.bakes()).single;
    expect(saved.created, bake.created);
    expect(saved.result, 'Bien');
    expect(saved.stages.single.hours, 5);
  });

  test('los datos sobreviven al cierre y reapertura del archivo SQLite',
      () async {
    final directory = await Directory.systemTemp.createTemp('panadero-test-');
    final path =
        '${directory.path}${Platform.pathSeparator}persistencia.sqlite';
    try {
      final first = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
              version: PanaderoStore.schemaVersion,
              onCreate: PanaderoStore.createSchema));
      final originalStore = PanaderoStore(first);
      final bake = Bake(
          id: 'persisted',
          recipe: exampleRecipes().last,
          created: DateTime(2026, 10, 17),
          notes: 'Conservar');
      await originalStore.saveBake(bake);
      await first.close();
      final reopened = await databaseFactoryFfi.openDatabase(path);
      try {
        final persisted = (await PanaderoStore(reopened).bakes()).single;
        expect(persisted.toJson(), bake.toJson());
        expect((await PanaderoStore(reopened).recipes()).length, 3);
      } finally {
        await reopened.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('rechaza una importación inválida completa sin escrituras parciales',
      () async {
    final recipes = await store.recipes();
    final invalid = Recipe(
        id: 'invalid',
        name: 'Imposible',
        category: 'Otro',
        formula: const Formula(water: 1, starterInGrams: true, starter: 1000));
    await expectLater(
        store.importTransfer(Transfer(
            recipes: [recipes.first, invalid], bakes: [], backup: false)),
        throwsFormatException);
    expect((await store.recipes()).length, 3);
    expect(await store.bakes(), isEmpty);
  });

  test('una etapa con fin anterior al inicio no se guarda', () async {
    final bake = Bake(
        id: 'invalid',
        recipe: exampleRecipes().first,
        created: DateTime.now(),
        stages: [
          FermentationStage(
              name: 'Bloque',
              start: DateTime(2026, 10, 17),
              end: DateTime(2026, 10, 16)),
        ]);
    await expectLater(store.saveBake(bake), throwsFormatException);
    expect(await store.bakes(), isEmpty);
  });
}
