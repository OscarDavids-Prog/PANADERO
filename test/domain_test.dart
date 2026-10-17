import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:panadero/domain.dart';

void main() {
  double sum(Calculation c) => [
        ...c.main,
        ...c.previous.expand((p) => p.ingredients)
      ].fold(0, (s, e) => s + e.amount);
  test('lactal exacto de 2 kg, sin contar dos veces la MM', () {
    final c = exampleRecipes()[0].formula.calculate();
    expect(c.flour, closeTo(1176.470588, 1e-6));
    expect(c.main[0].amount, closeTo(1076.470588, 1e-6));
    expect(c.main[1].amount, closeTo(605.882353, 1e-6));
    expect(c.starterMass, 200);
    expect(c.hydration, closeTo(60, 1e-9));
    expect(sum(c), closeTo(2000, 1e-9));
  });
  test('dual corregida de 3 kg, MM fija', () {
    final c = exampleRecipes()[1].formula.calculate();
    expect(c.total, closeTo(3000, 1e-9));
    expect(c.main[0].amount, closeTo(1544.1860465, 1e-6));
    expect(c.main[1].amount, closeTo(986.0465116, 1e-6));
    expect(c.starterMass, 400);
    expect(c.hydration, closeTo(68, 1e-9));
  });
  test('focaccia: 932 g, 80% agua, 40% MM y 20% harina prefermentada', () {
    final c = exampleRecipes()[2].formula.calculate();
    expect(c.main[0].amount, 400);
    expect(c.main[1].amount, 300);
    expect(c.total, 932);
    expect(c.hydration, 80);
    expect(c.starterPercent, 40);
    expect(c.prefermentedPercent, 20);
  });
  test('MM porcentual a hidratación distinta de 100%', () {
    final c = const Formula(
            base: 1000, water: 70, starter: 30, prefermentHydration: 50)
        .calculate();
    expect(c.main[0].amount, closeTo(800, 1e-9));
    expect(c.main[1].amount, closeTo(600, 1e-9));
    expect(c.starterMass, closeTo(300, 1e-9));
    expect(c.total, closeTo(1720, 1e-9));
  });
  test(
      'sin descuento muestra hidratación real y conserva MM fija en peso objetivo',
      () {
    final c = const Formula(
            base: 500,
            water: 70,
            discount: false,
            starterInGrams: true,
            starter: 100)
        .calculate();
    expect(c.hydration, closeTo(400 / 550 * 100, 1e-9));
    expect(c.total, 960);
    final target = const Formula(
            mode: CalculationMode.dough,
            base: 2000,
            water: 70,
            discount: false,
            starterInGrams: true,
            starter: 100)
        .calculate();
    expect(target.total, closeTo(2000, 1e-9));
    expect(target.starterMass, 100);
  });
  test('biga con inóculo incluido y tangzhong simultáneo', () {
    final c = const Formula(
            base: 1000,
            water: 72,
            preferment: Preferment.biga,
            starter: 20,
            prefermentHydration: 50,
            seedPercent: 10,
            scald: Scald.tangzhong,
            scaldPercent: 8,
            scaldRatio: 5)
        .calculate();
    final biga = c.previous.first.ingredients;
    expect(biga[0].amount, 190);
    expect(biga[1].amount, 90);
    expect(biga[2].amount, 20);
    expect(c.main[0].amount, 720);
    expect(c.main[1].amount, 220);
    expect(c.total, 1740);
    expect(sum(c), c.total);
  });
  test('poolish con levadura y refuerzo, peso final exacto', () {
    final c = const Formula(
            mode: CalculationMode.dough,
            base: 3000,
            preferment: Preferment.poolish,
            starter: 20,
            yeastSeed: true,
            seedPercent: 1,
            yeast: 0.2)
        .calculate();
    expect(c.total, closeTo(3000, 1e-9));
    expect(c.starterMass, 0);
    expect(c.previous.first.ingredients.last.name, 'Levadura del prefermento');
    expect(c.hydration, closeTo(70, 1e-9));
  });
  test('sin prefermento, solo levadura y yudane configurable', () {
    final c = const Formula(
            preferment: Preferment.none,
            yeast: 1,
            scald: Scald.yudane,
            scaldPercent: 10,
            scaldRatio: 1.5)
        .calculate();
    expect(c.previous.length, 1);
    expect(c.previous.single.ingredients[1].amount, 75);
    expect(c.starterMass, 0);
    expect(c.total, closeTo(865, 1e-9));
  });
  test(
      'rechaza negativos, no finitos, piezas inválidas y descuentos imposibles',
      () {
    for (final f in [
      const Formula(base: 0),
      const Formula(base: -1),
      const Formula(water: double.nan),
      const Formula(starter: double.infinity),
      const Formula(mode: CalculationMode.weights, base: 1e308, water: 1e308),
      const Formula(pieces: 0),
      const Formula(water: 5, starterInGrams: true, starter: 200),
      const Formula(starter: 300),
      const Formula(
          preferment: Preferment.biga,
          prefermentHydration: 10,
          seedPercent: 100),
    ]) {
      expect(f.calculate, throwsFormatException);
    }
  });
  test('balance de masa y objetivo para combinaciones de preparaciones', () {
    for (final pre in Preferment.values) {
      for (final scald in Scald.values) {
        for (final discount in [true, false]) {
          for (final grams in [true, false]) {
            for (final yeastSeed in [true, false]) {
              final f = Formula(
                  mode: CalculationMode.dough,
                  base: 2300,
                  water: 80,
                  preferment: pre,
                  starter: grams ? 100 : 15,
                  starterInGrams: grams,
                  prefermentHydration: 50,
                  scald: scald,
                  scaldPercent: 5,
                  scaldRatio: 1.5,
                  discount: discount,
                  yeastSeed: yeastSeed,
                  extras: const [ExtraIngredient('Aceite', 3)]);
              // Non-direct preferments always use flour percentage.
              if (pre != Preferment.starter && grams) continue;
              final c = f.calculate();
              expect(c.total, closeTo(2300, 1e-7));
              expect(sum(c), closeTo(c.total, 1e-9));
              expect(c.main.every((e) => e.amount >= 0), isTrue);
              if (discount) expect(c.hydration, closeTo(80, 1e-9));
            }
          }
        }
      }
    }
  });
  test('recetas y respaldo versionado conservan fórmula, instantánea y etapas',
      () {
    final recipe = exampleRecipes().first;
    final bake = Bake(
        id: 'bake',
        recipe: recipe,
        created: DateTime(2026, 10, 16),
        starterState: 'En pico',
        notes: 'Pliegues',
        result: 'Buena miga',
        stages: [
          FermentationStage(
              name: 'Bloque',
              start: DateTime(2026, 10, 16, 20),
              end: DateTime(2026, 10, 17, 1),
              ambient: 23,
              growth: 50)
        ]);
    final source =
        Transfer(recipes: [recipe], bakes: [bake], backup: true).encode();
    final decoded = Transfer.decode(source);
    expect(decoded.encode(), source);
    expect(decoded.bakes.single.stages.single.hours, 5);
    expect(decoded.bakes.single.recipe.formula.calculate().total,
        closeTo(2000, 1e-9));
  });
  test(
      'importación rechaza archivo vacío, corrupto, versión futura y tipos incorrectos',
      () {
    final source =
        Transfer(recipes: exampleRecipes(), bakes: [], backup: false).encode();
    for (final invalid in [
      '',
      '[]',
      '{}',
      source.replaceFirst('"version": 2', '"version": 99'),
      source.replaceFirst('"base": 2000.0', '"base": "2000"'),
      source.replaceFirst('"discount": true', '"discount": "true"'),
      jsonEncode({
        'format': 'panadero',
        'version': 1,
        'kind': 'recipes',
        'recipes': [],
        'bakes': []
      }),
    ]) {
      expect(() => Transfer.decode(invalid), throwsFormatException);
    }
  });
  test('etapas rechazan fin anterior y conservan temperaturas bajo cero', () {
    final stage = FermentationStage(
        name: 'Frío',
        start: DateTime(2026, 10, 17),
        end: DateTime(2026, 10, 16));
    expect(() => FermentationStage.fromJson(stage.toJson()),
        throwsFormatException);
    final cold =
        FermentationStage(name: 'Frío', start: DateTime.now(), fridge: -1);
    expect(FermentationStage.fromJson(cold.toJson()).fridge, -1);
  });
}
