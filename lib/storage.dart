import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'domain.dart';

class PanaderoStore {
  PanaderoStore(this.db);
  final Database db;
  static const schemaVersion = 2;

  static Future<PanaderoStore> open() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return PanaderoStore(await openDatabase(
      p.join(directory.path, 'panadero.sqlite'),
      version: schemaVersion,
      onCreate: createSchema,
      onUpgrade: upgradeSchema,
    ));
  }

  static Future<void> createSchema(Database db, int version) async {
    await db.execute(
        'CREATE TABLE recipes (id TEXT PRIMARY KEY, name TEXT NOT NULL, data TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE bakes (id TEXT PRIMARY KEY, created TEXT NOT NULL, data TEXT NOT NULL)');
    await db.execute('CREATE INDEX bakes_created ON bakes(created)');
    for (final recipe in exampleRecipes()) {
      await db.insert('recipes', recipeRow(recipe));
    }
    if (version >= 2) await _createPrepared(db);
  }

  static Future<void> _createPrepared(Database db) async {
    await db.execute(
        'CREATE TABLE prepared (id TEXT PRIMARY KEY, created TEXT NOT NULL, data TEXT NOT NULL)');
    await db.execute('CREATE INDEX prepared_created ON prepared(created)');
  }

  static Future<void> upgradeSchema(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createPrepared(db);
  }

  static Map<String, Object?> recipeRow(Recipe recipe) => {
        'id': recipe.id,
        'name': recipe.name,
        'data': jsonEncode(recipe.toJson()),
      };
  static Map<String, Object?> bakeRow(Bake bake) => {
        'id': bake.id,
        'created': bake.created.toUtc().toIso8601String(),
        'data': jsonEncode(bake.toJson()),
      };
  Future<List<Recipe>> recipes() async =>
      (await db.query('recipes', orderBy: 'name COLLATE NOCASE'))
          .map((r) => Recipe.fromJson(jsonDecode(r['data'] as String)))
          .toList();
  Future<List<Bake>> bakes() async =>
      (await db.query('bakes', orderBy: 'created DESC'))
          .map((r) => Bake.fromJson(jsonDecode(r['data'] as String)))
          .toList();
  Future<void> saveRecipe(Recipe recipe) async {
    Recipe.fromJson(recipe.toJson());
    await db.insert('recipes', recipeRow(recipe),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveBake(Bake bake) async {
    Bake.fromJson(bake.toJson());
    await db.insert('bakes', bakeRow(bake),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRecipe(String id) async {
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBake(String id) async {
    await db.delete('bakes', where: 'id = ?', whereArgs: [id]);
  }

  static Map<String, Object?> preparedRow(PreparedBatch prepared) => {
        'id': prepared.id,
        'created': prepared.created.toUtc().toIso8601String(),
        'data': jsonEncode(prepared.toJson()),
      };
  Future<List<PreparedBatch>> preparedBatches() async =>
      (await db.query('prepared', orderBy: 'created DESC'))
          .map((r) => PreparedBatch.fromJson(jsonDecode(r['data'] as String)))
          .toList();
  Future<void> savePrepared(PreparedBatch prepared) async {
    PreparedBatch.fromJson(prepared.toJson());
    await db.insert('prepared', preparedRow(prepared),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deletePrepared(String id) async {
    await db.delete('prepared', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> importTransfer(Transfer transfer) async {
    final validated = Transfer.decode(transfer.encode());
    // Imports are additive: a received file never overwrites a local record.
    await db.transaction((txn) async {
      final preparedIds = <String, String>{};
      for (final prepared in validated.prepared) {
        final id = newId();
        preparedIds[prepared.id] = id;
        await txn.insert('prepared', preparedRow(prepared.withId(id)));
      }
      for (final recipe in validated.recipes) {
        await txn.insert('recipes', recipeRow(recipe.withId(newId())));
      }
      for (final bake in validated.bakes) {
        final snapshot = bake.prepared;
        final imported = bake.withId(newId()).copy(
            prepared: snapshot?.withId(preparedIds[snapshot.id] ?? newId()));
        await txn.insert('bakes', bakeRow(imported));
      }
    });
  }
}
