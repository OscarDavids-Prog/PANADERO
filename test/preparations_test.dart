import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panadero/diary.dart';
import 'package:panadero/domain.dart';
import 'package:panadero/preparations.dart';
import 'package:panadero/storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  PreparedBatch batch(
          {StarterBuild build = const StarterBuild(), String id = 'batch'}) =>
      PreparedBatch(
          id: id,
          name: 'Refresco de prueba',
          created: DateTime(2026, 10, 17, 11),
          build: build,
          notes: 'En pico');

  test('refresco 1:2:2 y MM inicial al 100%', () {
    final c = const StarterBuild().calculate();
    expect(c.seed, 20);
    expect(c.addedFlour, 40);
    expect(c.addedWater, 40);
    expect(c.total, 100);
    expect(c.totalFlour, 50);
    expect(c.hydration, 100);
  });
  test('refresco considera hidratación inicial distinta y relación 1:2:1', () {
    final c = const StarterBuild(
            seedMass: 30, seedHydration: 50, flourRatio: 2, waterRatio: 1)
        .calculate();
    expect(c.total, 120);
    expect(c.totalFlour, 80);
    expect(c.totalWater, 40);
    expect(c.hydration, 50);
  });
  test('biga: 200 g harina total, 50% agua, 20 g MM incluida', () {
    final c = const StarterBuild(kind: StarterBuildKind.biga).calculate();
    expect(c.seed, 20);
    expect(c.addedFlour, 190);
    expect(c.addedWater, 90);
    expect(c.total, 300);
    expect(c.hydration, 50);
  });
  test('poolish: 200 g harina total y MM al 50%', () {
    final c = const StarterBuild(
            kind: StarterBuildKind.poolish,
            hydration: 100,
            seedHydration: 50,
            seedPercent: 15)
        .calculate();
    expect(c.seed, 30);
    expect(c.addedFlour, 180);
    expect(c.addedWater, 190);
    expect(c.total, 400);
    expect(c.hydration, 100);
  });
  test('rechaza refrescos y prefermentos imposibles o no finitos', () {
    for (final build in [
      const StarterBuild(seedMass: 0),
      const StarterBuild(flourRatio: 0),
      const StarterBuild(waterRatio: -1),
      const StarterBuild(seedHydration: double.nan),
      const StarterBuild(seedMass: 1e308, flourRatio: 1e308),
      const StarterBuild(kind: StarterBuildKind.biga, seedPercent: 0),
      const StarterBuild(
          kind: StarterBuildKind.biga, hydration: 1, seedPercent: 100),
    ]) {
      expect(build.calculate, throwsFormatException);
    }
  });
  test('respaldo v2 conserva preparado y copia vinculada; importa v1', () {
    final prepared = batch();
    final bake = Bake(
        id: 'bake',
        recipe: exampleRecipes().first,
        created: DateTime.now(),
        prepared: prepared);
    final source =
        Transfer(recipes: [], bakes: [bake], prepared: [prepared], backup: true)
            .encode();
    final decoded = Transfer.decode(source);
    expect(decoded.encode(), source);
    expect(decoded.bakes.single.prepared!.toJson(), prepared.toJson());
    expect(bake.copy(clearPrepared: true).prepared, isNull);
    final legacyBake = bake.toJson()..remove('prepared');
    final legacy = jsonEncode({
      'format': 'panadero',
      'version': 1,
      'kind': 'backup',
      'recipes': [],
      'bakes': [legacyBake]
    });
    expect(Transfer.decode(legacy).bakes.single.prepared, isNull);
    expect(Transfer.decode(legacy).prepared, isEmpty);
  });
  test(
      'respaldo solo de preparados y rechazo de preparados en archivo de recetas',
      () {
    final transfer =
        Transfer(recipes: [], bakes: [], prepared: [batch()], backup: true);
    expect(Transfer.decode(transfer.encode()).prepared.length, 1);
    expect(
        () => Transfer.decode(
            transfer.encode().replaceFirst('"backup"', '"recipes"')),
        throwsFormatException);
  });

  group('almacén de preparados', () {
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

    test('editar y borrar preparado no cambia la copia de la amasada',
        () async {
      final original = batch();
      await store.savePrepared(original);
      final bake = Bake(
          id: 'bake',
          recipe: exampleRecipes().last,
          created: DateTime.now(),
          prepared: original);
      await store.saveBake(bake);
      await store.savePrepared(PreparedBatch(
          id: original.id,
          name: 'Otro',
          created: original.created,
          build: const StarterBuild(seedMass: 50)));
      expect((await store.preparedBatches()).single.name, 'Otro');
      await store.deletePrepared(original.id);
      expect(await store.preparedBatches(), isEmpty);
      expect(
          (await store.bakes()).single.prepared!.toJson(), original.toJson());
    });
    test('importación aditiva remapea vínculos sin perder la copia histórica',
        () async {
      final prepared = batch();
      final historical = PreparedBatch(
          id: prepared.id,
          name: 'Copia histórica',
          created: prepared.created,
          build: const StarterBuild(seedMass: 10));
      final bake = Bake(
          id: 'bake',
          recipe: exampleRecipes().first,
          created: DateTime.now(),
          prepared: historical);
      final data = Transfer(
          recipes: [], bakes: [bake], prepared: [prepared], backup: true);
      await store.importTransfer(data);
      await store.importTransfer(data);
      final imported = await store.preparedBatches();
      final bakes = await store.bakes();
      expect(imported.map((p) => p.id).toSet().length, 2);
      expect(bakes.length, 2);
      for (final bake in bakes) {
        expect(imported.any((p) => p.id == bake.prepared!.id), isTrue);
        expect(bake.prepared!.name, 'Copia histórica');
        expect(bake.prepared!.build.seedMass, 10);
      }
    });

    testWidgets('editor guarda refresco con fecha manual y coma decimal',
        (tester) async {
      final uiStore = _WidgetStore(store.db);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => PreparedEditor(store: uiStore))),
                      child: const Text('Abrir'))))));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('prepared-created')), '2026-10-16 20:30');
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('prepared-seedMass')), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.enterText(
          find.byKey(const ValueKey('prepared-seedMass')), '25,5');
      await tester.pump();
      tester.testTextInput.hide();
      await tester.scrollUntilVisible(find.text('Guardar preparado'), 250,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Total preparado: 127.5 g'), findsOneWidget);
      await tester.tap(find.text('Guardar preparado'));
      await tester.pumpAndSettle();
      final saved = (await uiStore.preparedBatches()).single;
      expect(saved.build.seedMass, 25.5);
      expect(saved.created, DateTime(2026, 10, 16, 20, 30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('amasada vincula y desvincula preparado sin modificar fórmula',
        (tester) async {
      final uiStore = _WidgetStore(store.db);
      final prepared = batch();
      await uiStore.savePrepared(prepared);
      final bake = Bake(
          id: 'bake', recipe: exampleRecipes().last, created: DateTime.now());
      await uiStore.saveBake(bake);
      await tester.pumpWidget(
          MaterialApp(home: BakePage(store: uiStore, initial: bake)));
      await tester.tap(find.text('Vincular preparado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(prepared.name));
      await tester.pumpAndSettle();
      expect((await uiStore.bakes()).single.prepared!.id, prepared.id);
      expect(
          (await uiStore.bakes()).single.recipe.toJson(), bake.recipe.toJson());
      await tester.tap(find.text('Quitar vínculo'));
      await tester.pumpAndSettle();
      expect((await uiStore.bakes()).single.prepared, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  test('migración SQLite v1 a v2 preserva recetas y amasadas', () async {
    sqfliteFfiInit();
    final directory =
        await Directory.systemTemp.createTemp('panadero-migration-');
    final path = '${directory.path}${Platform.pathSeparator}migration.sqlite';
    try {
      final legacy = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1, onCreate: PanaderoStore.createSchema));
      final bake = Bake(
          id: 'legacy',
          recipe: exampleRecipes().first,
          created: DateTime.now());
      final legacyData = bake.toJson()..remove('prepared');
      await legacy.insert('bakes', {
        'id': bake.id,
        'created': bake.created.toUtc().toIso8601String(),
        'data': jsonEncode(legacyData)
      });
      await legacy.close();
      final upgraded = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
              version: PanaderoStore.schemaVersion,
              onUpgrade: PanaderoStore.upgradeSchema));
      try {
        final store = PanaderoStore(upgraded);
        expect((await store.recipes()).length, 3);
        expect((await store.bakes()).single.id, 'legacy');
        expect((await store.bakes()).single.prepared, isNull);
        expect(await store.preparedBatches(), isEmpty);
        await store.savePrepared(batch());
        expect((await store.preparedBatches()).single.build.calculate().total,
            100);
      } finally {
        await upgraded.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

class _WidgetStore extends PanaderoStore {
  _WidgetStore(super.db);
  final _prepared = <String, PreparedBatch>{};
  final _bakes = <String, Bake>{};
  @override
  Future<void> savePrepared(PreparedBatch prepared) async {
    _prepared[prepared.id] = PreparedBatch.fromJson(prepared.toJson());
  }

  @override
  Future<List<PreparedBatch>> preparedBatches() async =>
      _prepared.values.toList();
  @override
  Future<void> saveBake(Bake bake) async {
    _bakes[bake.id] = Bake.fromJson(bake.toJson());
  }

  @override
  Future<List<Bake>> bakes() async => _bakes.values.toList();
}
