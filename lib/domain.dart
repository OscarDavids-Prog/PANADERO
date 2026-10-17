import 'dart:convert';
import 'dart:math';

String newId() {
  final random = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch}-${List.generate(12, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

enum CalculationMode { flour, dough, weights }

enum Preferment { none, starter, poolish, biga }

enum Scald { none, tangzhong, yudane }

class ExtraIngredient {
  const ExtraIngredient(this.name, this.amount);
  final String name;
  final double amount;
  Map<String, Object?> toJson() => {'name': name, 'amount': amount};
  factory ExtraIngredient.fromJson(Object? value) {
    final data = objectMap(value);
    return ExtraIngredient(text(data, 'name'), number(data, 'amount'));
  }
}

class Formula {
  const Formula({
    this.mode = CalculationMode.flour,
    this.base = 500,
    this.water = 70,
    this.salt = 2,
    this.yeast = 0,
    this.preferment = Preferment.starter,
    this.starterInGrams = false,
    this.starter = 20,
    this.prefermentHydration = 100,
    this.seedHydration = 100,
    this.seedPercent = 10,
    this.yeastSeed = false,
    this.scald = Scald.none,
    this.scaldPercent = 5,
    this.scaldRatio = 5,
    this.discount = true,
    this.pieces = 1,
    this.extras = const [],
  });

  final CalculationMode mode;
  final double base, water, salt, yeast;
  final Preferment preferment;
  final bool starterInGrams, yeastSeed, discount;
  final double starter, prefermentHydration, seedHydration, seedPercent;
  final Scald scald;
  final double scaldPercent, scaldRatio;
  final int pieces;
  final List<ExtraIngredient> extras;

  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'base': base,
        'water': water,
        'salt': salt,
        'yeast': yeast,
        'preferment': preferment.name,
        'starterInGrams': starterInGrams,
        'starter': starter,
        'prefermentHydration': prefermentHydration,
        'seedHydration': seedHydration,
        'seedPercent': seedPercent,
        'yeastSeed': yeastSeed,
        'scald': scald.name,
        'scaldPercent': scaldPercent,
        'scaldRatio': scaldRatio,
        'discount': discount,
        'pieces': pieces,
        'extras': extras.map((e) => e.toJson()).toList(),
      };

  factory Formula.fromJson(Object? value) {
    final d = objectMap(value);
    final pieces = number(d, 'pieces');
    if (pieces < 1 || pieces != pieces.roundToDouble()) {
      throw const FormatException(
          'La cantidad de piezas debe ser entera y positiva.');
    }
    final formula = Formula(
      mode: enumValue(CalculationMode.values, d, 'mode'),
      base: number(d, 'base'),
      water: number(d, 'water'),
      salt: number(d, 'salt'),
      yeast: number(d, 'yeast'),
      preferment: enumValue(Preferment.values, d, 'preferment'),
      starterInGrams: boolean(d, 'starterInGrams'),
      starter: number(d, 'starter'),
      prefermentHydration: number(d, 'prefermentHydration'),
      seedHydration: number(d, 'seedHydration'),
      seedPercent: number(d, 'seedPercent'),
      yeastSeed: boolean(d, 'yeastSeed'),
      scald: enumValue(Scald.values, d, 'scald'),
      scaldPercent: number(d, 'scaldPercent'),
      scaldRatio: number(d, 'scaldRatio'),
      discount: boolean(d, 'discount'),
      pieces: pieces.toInt(),
      extras: array(d, 'extras').map(ExtraIngredient.fromJson).toList(),
    );
    formula.calculate();
    return formula;
  }

  Calculation calculate() {
    final values = [
      base,
      water,
      salt,
      yeast,
      starter,
      prefermentHydration,
      seedHydration,
      seedPercent,
      scaldPercent,
      scaldRatio,
      ...extras.map((e) => e.amount)
    ];
    if (values.any((v) => !v.isFinite || v < 0) || base <= 0 || pieces < 1) {
      throw const FormatException(
          'Usá valores finitos, no negativos, y una base y cantidad de piezas mayores que cero.');
    }
    if (extras.any((e) => e.name.trim().isEmpty)) {
      throw const FormatException(
          'Cada ingrediente adicional necesita un nombre.');
    }
    if (mode == CalculationMode.weights) {
      final ingredients = [
        ExtraIngredient('Harina', base),
        ExtraIngredient('Agua', water),
        ExtraIngredient('Sal', salt),
        ExtraIngredient('Levadura', yeast),
        ...extras,
      ];
      final total = ingredients.fold(0.0, (s, e) => s + e.amount);
      if (!total.isFinite ||
          !(water / base * 100).isFinite ||
          ingredients.any((e) => !(e.amount / base * 100).isFinite)) {
        throw const FormatException(
            'El peso o porcentaje calculado está fuera de rango.');
      }
      return Calculation(
        baseFlour: base,
        flour: base,
        totalWater: water,
        main: ingredients,
        previous: const [],
        total: total,
        starterMass: 0,
        prefermentedFlour: 0,
        pieces: pieces,
      );
    }
    final preHyd = prefermentHydration / 100;
    final seedHyd = seedHydration / 100;
    final hasPre = preferment != Preferment.none;
    final direct = preferment == Preferment.starter;
    final fixed = hasPre && direct && starterInGrams ? starter : 0.0;
    final preFlourFactor = !hasPre || fixed > 0 || (direct && starterInGrams)
        ? 0.0
        : direct
            ? starter / 100 / (1 + preHyd)
            : starter / 100;
    final scaldFlourFactor = scald == Scald.none ? 0.0 : scaldPercent / 100;
    final seedYeastFactor = hasPre && !direct && yeastSeed
        ? preFlourFactor * seedPercent / 100
        : 0.0;
    final extraFactor = extras.fold(0.0, (s, e) => s + e.amount / 100);
    var factor = 1 +
        water / 100 +
        salt / 100 +
        yeast / 100 +
        extraFactor +
        seedYeastFactor;
    if (!discount) {
      factor +=
          preFlourFactor * (1 + preHyd) + scaldFlourFactor * (1 + scaldRatio);
    }
    final flourBase = mode == CalculationMode.dough
        ? (base - (discount ? 0 : fixed)) / factor
        : base;
    final preFlour = fixed / (1 + preHyd) + flourBase * preFlourFactor;
    final preWater = preFlour * preHyd;
    final scaldFlour = flourBase * scaldFlourFactor;
    final scaldWater = scaldFlour * scaldRatio;
    final mainFlour = flourBase - (discount ? preFlour + scaldFlour : 0);
    final mainWater =
        flourBase * water / 100 - (discount ? preWater + scaldWater : 0);
    final seed = hasPre && !direct ? preFlour * seedPercent / 100 : 0.0;
    final seedFlour = yeastSeed ? 0.0 : seed / (1 + seedHyd);
    final seedWater = seedFlour * seedHyd;
    if (flourBase <= 0 ||
        mainFlour < -1e-8 ||
        mainWater < -1e-8 ||
        preFlour - seedFlour < -1e-8 ||
        preWater - seedWater < -1e-8) {
      throw const FormatException(
        'La preparación consume más harina o agua de la disponible. '
        'Revisá MM, inóculo, hidratación y precocción.',
      );
    }
    final previous = <Preparation>[];
    if (hasPre) {
      previous.add(Preparation(
        direct
            ? 'Masa madre lista para usar'
            : preferment == Preferment.poolish
                ? 'Poolish'
                : 'Biga',
        direct
            ? [
                ExtraIngredient(
                    'MM ($prefermentHydration % hid.)', preFlour + preWater),
              ]
            : [
                ExtraIngredient('Harina', max(0, preFlour - seedFlour)),
                ExtraIngredient('Agua', max(0, preWater - seedWater)),
                ExtraIngredient(
                    yeastSeed ? 'Levadura del prefermento' : 'MM de inóculo',
                    seed),
              ],
      ));
    }
    if (scald != Scald.none) {
      previous.add(Preparation(
        scald == Scald.tangzhong ? 'Tangzhong' : 'Yudane',
        [
          ExtraIngredient('Harina', scaldFlour),
          ExtraIngredient('Agua', scaldWater)
        ],
      ));
    }
    final main = [
      ExtraIngredient('Harina', max(0, mainFlour)),
      ExtraIngredient('Agua', max(0, mainWater)),
      ExtraIngredient('Sal', flourBase * salt / 100),
      ExtraIngredient('Levadura adicional', flourBase * yeast / 100),
      ...extras.map((e) => ExtraIngredient(e.name, flourBase * e.amount / 100)),
    ];
    final total = [...main, ...previous.expand((p) => p.ingredients)]
        .fold(0.0, (s, e) => s + e.amount);
    final actualFlour = mainFlour + preFlour + scaldFlour;
    final actualWater = mainWater + preWater + scaldWater;
    if (!total.isFinite ||
        total <= 0 ||
        !actualFlour.isFinite ||
        actualFlour <= 0 ||
        !(actualWater / actualFlour * 100).isFinite) {
      throw const FormatException('El peso calculado está fuera de rango.');
    }
    return Calculation(
      baseFlour: flourBase,
      flour: actualFlour,
      totalWater: actualWater,
      main: main,
      previous: previous,
      total: total,
      starterMass: direct
          ? preFlour + preWater
          : yeastSeed
              ? 0
              : seed,
      prefermentedFlour: preFlour,
      pieces: pieces,
    );
  }
}

class Preparation {
  const Preparation(this.name, this.ingredients);
  final String name;
  final List<ExtraIngredient> ingredients;
}

class Calculation {
  const Calculation({
    required this.baseFlour,
    required this.flour,
    required this.totalWater,
    required this.main,
    required this.previous,
    required this.total,
    required this.starterMass,
    required this.prefermentedFlour,
    required this.pieces,
  });
  final double baseFlour,
      flour,
      totalWater,
      total,
      starterMass,
      prefermentedFlour;
  final int pieces;
  final List<ExtraIngredient> main;
  final List<Preparation> previous;
  double get hydration => totalWater / flour * 100;
  double get starterPercent => starterMass / flour * 100;
  double get prefermentedPercent => prefermentedFlour / flour * 100;
}

class Recipe {
  const Recipe(
      {required this.id,
      required this.name,
      required this.category,
      required this.formula,
      this.instructions = ''});
  final String id, name, category, instructions;
  final Formula formula;
  Recipe withId(String id) => Recipe(
      id: id,
      name: name,
      category: category,
      formula: formula,
      instructions: instructions);
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'instructions': instructions,
        'formula': formula.toJson(),
      };
  factory Recipe.fromJson(Object? value) {
    final d = objectMap(value);
    return Recipe(
        id: text(d, 'id'),
        name: text(d, 'name'),
        category: text(d, 'category'),
        instructions: text(d, 'instructions', empty: true),
        formula: Formula.fromJson(d['formula']));
  }
}

class FermentationStage {
  const FermentationStage({
    required this.name,
    required this.start,
    this.end,
    this.ambient,
    this.dough,
    this.fridge,
    this.growth,
    this.notes = '',
  });
  final String name, notes;
  final DateTime start;
  final DateTime? end;
  final double? ambient, dough, fridge, growth;
  double? get hours =>
      end == null ? null : end!.difference(start).inMicroseconds / 3600000000;
  Map<String, Object?> toJson() => {
        'name': name,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'ambient': ambient,
        'dough': dough,
        'fridge': fridge,
        'growth': growth,
        'notes': notes,
      };
  factory FermentationStage.fromJson(Object? value) {
    final d = objectMap(value);
    final start = date(d, 'start');
    final end = d['end'] == null ? null : date(d, 'end');
    if (end != null && end.isBefore(start)) {
      throw const FormatException('El fin de etapa es anterior al inicio.');
    }
    final growth = optionalNumber(d, 'growth');
    if (growth != null && growth < 0) {
      throw const FormatException('El crecimiento no puede ser negativo.');
    }
    return FermentationStage(
        name: text(d, 'name'),
        start: start,
        end: end,
        ambient: optionalNumber(d, 'ambient'),
        dough: optionalNumber(d, 'dough'),
        fridge: optionalNumber(d, 'fridge'),
        growth: growth,
        notes: text(d, 'notes', empty: true));
  }
}

enum StarterBuildKind { refresh, biga, poolish }

class StarterBuild {
  const StarterBuild({
    this.kind = StarterBuildKind.refresh,
    this.seedMass = 20,
    this.flourRatio = 2,
    this.waterRatio = 2,
    this.seedHydration = 100,
    this.flour = 200,
    this.hydration = 50,
    this.seedPercent = 10,
  });
  final StarterBuildKind kind;
  final double seedMass, flourRatio, waterRatio, seedHydration;
  final double flour, hydration, seedPercent;

  StarterBuildResult calculate() {
    if ([
      seedMass,
      flourRatio,
      waterRatio,
      seedHydration,
      flour,
      hydration,
      seedPercent
    ].any((v) => !v.isFinite || v < 0)) {
      throw const FormatException('Usá cantidades finitas y no negativas.');
    }
    if (kind == StarterBuildKind.refresh) {
      if (seedMass <= 0 || flourRatio <= 0) {
        throw const FormatException(
            'El refresco necesita MM inicial y harina nueva mayores que cero.');
      }
      final seedFlour = seedMass / (1 + seedHydration / 100);
      return StarterBuildResult(
        seed: seedMass,
        addedFlour: seedMass * flourRatio,
        addedWater: seedMass * waterRatio,
        totalFlour: seedFlour + seedMass * flourRatio,
        totalWater: seedMass - seedFlour + seedMass * waterRatio,
      ).validated();
    }
    if (flour <= 0 || seedPercent <= 0) {
      throw const FormatException(
          'El prefermento necesita harina e inóculo de MM mayores que cero.');
    }
    final calculated = Formula(
      base: flour,
      water: hydration,
      salt: 0,
      preferment:
          kind == StarterBuildKind.biga ? Preferment.biga : Preferment.poolish,
      starter: 100,
      prefermentHydration: hydration,
      seedHydration: seedHydration,
      seedPercent: seedPercent,
    ).calculate();
    final ingredients = calculated.previous.single.ingredients;
    return StarterBuildResult(
      seed: ingredients[2].amount,
      addedFlour: ingredients[0].amount,
      addedWater: ingredients[1].amount,
      totalFlour: flour,
      totalWater: flour * hydration / 100,
    ).validated();
  }

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'seedMass': seedMass,
        'flourRatio': flourRatio,
        'waterRatio': waterRatio,
        'seedHydration': seedHydration,
        'flour': flour,
        'hydration': hydration,
        'seedPercent': seedPercent,
      };
  factory StarterBuild.fromJson(Object? value) {
    final d = objectMap(value);
    final build = StarterBuild(
      kind: enumValue(StarterBuildKind.values, d, 'kind'),
      seedMass: number(d, 'seedMass'),
      flourRatio: number(d, 'flourRatio'),
      waterRatio: number(d, 'waterRatio'),
      seedHydration: number(d, 'seedHydration'),
      flour: number(d, 'flour'),
      hydration: number(d, 'hydration'),
      seedPercent: number(d, 'seedPercent'),
    );
    build.calculate();
    return build;
  }
}

class StarterBuildResult {
  const StarterBuildResult(
      {required this.seed,
      required this.addedFlour,
      required this.addedWater,
      required this.totalFlour,
      required this.totalWater});
  final double seed, addedFlour, addedWater, totalFlour, totalWater;
  double get total => seed + addedFlour + addedWater;
  double get hydration => totalWater / totalFlour * 100;
  StarterBuildResult validated() {
    if ([seed, addedFlour, addedWater, totalFlour, totalWater, total, hydration]
            .any((v) => !v.isFinite || v < 0) ||
        totalFlour <= 0 ||
        total <= 0) {
      throw const FormatException(
          'El preparado calculado está fuera de rango.');
    }
    return this;
  }
}

class PreparedBatch {
  const PreparedBatch(
      {required this.id,
      required this.name,
      required this.created,
      required this.build,
      this.notes = ''});
  final String id, name, notes;
  final DateTime created;
  final StarterBuild build;
  PreparedBatch withId(String id) => PreparedBatch(
      id: id, name: name, created: created, build: build, notes: notes);
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'created': created.toIso8601String(),
        'build': build.toJson(),
        'notes': notes,
      };
  factory PreparedBatch.fromJson(Object? value) {
    final d = objectMap(value);
    return PreparedBatch(
        id: text(d, 'id'),
        name: text(d, 'name'),
        created: date(d, 'created'),
        build: StarterBuild.fromJson(d['build']),
        notes: text(d, 'notes', empty: true));
  }
}

class Bake {
  const Bake(
      {required this.id,
      required this.recipe,
      required this.created,
      this.starterState = '',
      this.notes = '',
      this.result = '',
      this.stages = const [],
      this.prepared});
  final String id, starterState, notes, result;
  final Recipe recipe;
  final DateTime created;
  final List<FermentationStage> stages;
  final PreparedBatch? prepared;
  Bake copy(
          {List<FermentationStage>? stages,
          String? starterState,
          String? notes,
          String? result,
          PreparedBatch? prepared,
          bool clearPrepared = false}) =>
      Bake(
          id: id,
          recipe: recipe,
          created: created,
          stages: stages ?? this.stages,
          starterState: starterState ?? this.starterState,
          notes: notes ?? this.notes,
          result: result ?? this.result,
          prepared: clearPrepared ? null : prepared ?? this.prepared);
  Bake withId(String id) => Bake(
      id: id,
      recipe: recipe,
      created: created,
      stages: stages,
      starterState: starterState,
      notes: notes,
      result: result,
      prepared: prepared);
  Map<String, Object?> toJson() => {
        'id': id,
        'recipe': recipe.toJson(),
        'created': created.toIso8601String(),
        'starterState': starterState,
        'notes': notes,
        'result': result,
        'stages': stages.map((s) => s.toJson()).toList(),
        'prepared': prepared?.toJson(),
      };
  factory Bake.fromJson(Object? value) {
    final d = objectMap(value);
    return Bake(
        id: text(d, 'id'),
        recipe: Recipe.fromJson(d['recipe']),
        created: date(d, 'created'),
        starterState: text(d, 'starterState', empty: true),
        notes: text(d, 'notes', empty: true),
        result: text(d, 'result', empty: true),
        stages: array(d, 'stages').map(FermentationStage.fromJson).toList(),
        prepared: d['prepared'] == null
            ? null
            : PreparedBatch.fromJson(d['prepared']));
  }
}

class Transfer {
  const Transfer(
      {required this.recipes,
      required this.bakes,
      required this.backup,
      this.prepared = const []});
  final List<Recipe> recipes;
  final List<Bake> bakes;
  final bool backup;
  final List<PreparedBatch> prepared;
  String encode() => const JsonEncoder.withIndent('  ').convert({
        'format': 'panadero',
        'version': 2,
        'kind': backup ? 'backup' : 'recipes',
        'recipes': recipes.map((r) => r.toJson()).toList(),
        'bakes': bakes.map((b) => b.toJson()).toList(),
        'prepared': prepared.map((p) => p.toJson()).toList(),
      });
  factory Transfer.decode(String source) {
    final d = objectMap(jsonDecode(source));
    if (d['format'] != 'panadero' ||
        ![1, 2].contains(d['version']) ||
        !['backup', 'recipes'].contains(d['kind'])) {
      throw const FormatException(
          'Formato o versión de archivo no compatible.');
    }
    final recipes = array(d, 'recipes').map(Recipe.fromJson).toList();
    final bakes = array(d, 'bakes').map(Bake.fromJson).toList();
    final prepared = d['version'] == 1
        ? <PreparedBatch>[]
        : array(d, 'prepared').map(PreparedBatch.fromJson).toList();
    if (d['kind'] == 'recipes' && (bakes.isNotEmpty || prepared.isNotEmpty)) {
      throw const FormatException(
          'Un archivo de recetas no debe contener amasadas.');
    }
    if (recipes.isEmpty && bakes.isEmpty && prepared.isEmpty) {
      throw const FormatException(
          'El archivo no contiene recetas, amasadas ni preparados.');
    }
    return Transfer(
        recipes: recipes,
        bakes: bakes,
        prepared: prepared,
        backup: d['kind'] == 'backup');
  }
}

Map<String, Object?> objectMap(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Se esperaba un objeto JSON.');
  }
  return value;
}

List<Object?> array(Map<String, Object?> d, String key) {
  final value = d[key];
  if (value is! List) throw FormatException('Lista inválida: $key.');
  return value.cast<Object?>();
}

String text(Map<String, Object?> d, String key, {bool empty = false}) {
  final value = d[key];
  if (value is! String || (!empty && value.trim().isEmpty)) {
    throw FormatException('Texto inválido: $key.');
  }
  return value;
}

double number(Map<String, Object?> d, String key) {
  final value = d[key];
  if (value is! num || !value.isFinite) {
    throw FormatException('Número inválido: $key.');
  }
  return value.toDouble();
}

double? optionalNumber(Map<String, Object?> d, String key) =>
    d[key] == null ? null : number(d, key);
bool boolean(Map<String, Object?> d, String key) {
  final value = d[key];
  if (value is! bool) throw FormatException('Valor lógico inválido: $key.');
  return value;
}

T enumValue<T extends Enum>(
    List<T> values, Map<String, Object?> d, String key) {
  for (final value in values) {
    if (value.name == d[key]) return value;
  }
  throw FormatException('Opción desconocida: $key.');
}

DateTime date(Map<String, Object?> d, String key) {
  final value = DateTime.tryParse(text(d, key));
  if (value == null) throw FormatException('Fecha inválida: $key.');
  return value;
}

List<Recipe> exampleRecipes() => [
      Recipe(
          id: 'example-lactal',
          name: 'Lactal · 2 kg',
          category: 'Lactal / Molde',
          formula: const Formula(
              mode: CalculationMode.dough,
              base: 2000,
              water: 60,
              starterInGrams: true,
              starter: 200,
              pieces: 2,
              extras: [
                ExtraIngredient('Manteca', 4),
                ExtraIngredient('Azúcar', 4)
              ]),
          instructions: 'Mezclar y reposar. Incorporar sal y luego manteca. '
              'Registrar bloque, formado y fermentación en molde. Horno orientativo: '
              '180–190 °C, 35–45 min; ajustar al horno y tamaño. '
              'La hidratación indicada cuenta agua, no la humedad de la manteca.'),
      Recipe(
          id: 'example-dual',
          name: 'Masa dual · 3 kg',
          category: 'Pizza / Rústico',
          formula: const Formula(
              mode: CalculationMode.dough,
              base: 3000,
              water: 68,
              starterInGrams: true,
              starter: 400,
              extras: [ExtraIngredient('Aceite de oliva', 2)]),
          instructions: 'Base para pizza o pan rústico. Registrar pliegues, '
              'crecimiento al entrar al frío y fermentación final según destino.'),
      Recipe(
          id: 'example-focaccia',
          name: 'Focaccia · 200 g de MM',
          category: 'Focaccia',
          formula: const Formula(
              base: 500,
              water: 80,
              salt: 2.4,
              starterInGrams: true,
              starter: 200,
              extras: [ExtraIngredient('Aceite de oliva', 4)]),
          instructions:
              'Referencia: asadera de 30 × 40 cm. Mezclar y reposar 30 min. '
              'Agregar sal y aceite; realizar 3–4 tandas de pliegues durante unas 2 h. '
              'Retardo orientativo de 24 h en heladera; observar la masa. '
              'Pasar a asadera aceitada y dejar expandir antes de hacer los hoyuelos. '
              'Horno orientativo: 230–240 °C, 20–25 min. '
              'Aceite, sal y demás cubierta van aparte del peso de masa. '
              'Los tiempos no son garantías de fermentación.'),
    ];
