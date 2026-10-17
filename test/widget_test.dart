import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panadero/domain.dart';
import 'package:panadero/editor.dart';

void main() {
  Future<void> openEditor(WidgetTester tester, Formula formula,
      {Future<void> Function(Recipe)? onSave}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RecipeEditor(
      initial: Recipe(
          id: 'test', name: 'Prueba', category: 'Otro', formula: formula),
      onSave: onSave ?? (_) async {},
      onStart: (_) async {},
    ))));
  }

  testWidgets('mantiene cálculo por pesos en pantalla angosta', (tester) async {
    await openEditor(
        tester,
        const Formula(
            mode: CalculationMode.weights,
            base: 1000,
            water: 650,
            salt: 20,
            yeast: 10));
    await tester.scrollUntilVisible(find.text('1680 g'), 400,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('650 g · 65 %'), findsOneWidget);
    expect(find.text('20 g · 2 %'), findsOneWidget);
    expect(find.text('10 g · 1 %'), findsOneWidget);
    expect(find.text('1680 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'muestra error explícito y no permite guardar descuentos imposibles',
      (tester) async {
    await openEditor(tester,
        const Formula(base: 500, water: 5, starterInGrams: true, starter: 200));
    await tester.scrollUntilVisible(find.text('Guardar receta'), 400,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('consume más harina o agua'), findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar receta'));
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guarda receta con coma decimal y cantidades calculadas',
      (tester) async {
    Recipe? saved;
    await openEditor(tester, const Formula(), onSave: (r) async {
      saved = r;
    });
    final waterField = find.byKey(const ValueKey('input-water'));
    await tester.scrollUntilVisible(waterField, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(waterField, '72,5');
    await tester.pump();
    tester.testTextInput.hide();
    await tester.scrollUntilVisible(find.text('Guardar receta'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Guardar receta'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.formula.water, 72.5);
    expect(saved!.formula.calculate().hydration, closeTo(72.5, 1e-9));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'porcentajes muestran gramos junto a cada adicional y se actualizan',
      (tester) async {
    await openEditor(tester, exampleRecipes().first.formula);
    await tester.scrollUntilVisible(find.text('Ingredientes adicionales'), 300,
        scrollable: find.byType(Scrollable).first);
    final amountField = find
        .byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Cantidad (%)')
        .first;
    await tester.scrollUntilVisible(amountField, 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('47.06 g a pesar'), findsNWidgets(2));
    await tester.enterText(amountField, '8');
    await tester.pump();
    expect(find.text('91.95 g a pesar'), findsOneWidget);
    expect(find.text('45.98 g a pesar'), findsOneWidget);
    expect(find.text('47.06 g a pesar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gramos muestran el porcentaje junto a ingredientes adicionales',
      (tester) async {
    await openEditor(
        tester,
        const Formula(
          mode: CalculationMode.weights,
          base: 1000,
          water: 650,
          extras: [ExtraIngredient('Aceite', 30)],
        ));
    final amountField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Cantidad (g)');
    await tester.scrollUntilVisible(amountField, 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('3 % del peso de harina base'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('agua muestra gramos totales y gramos descontados a agregar',
      (tester) async {
    await openEditor(tester, exampleRecipes().last.formula);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('input-water')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('400 g de agua total objetivo · 300 g a agregar'),
        findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('input-water')), '70');
    await tester.pump();
    expect(find.text('350 g de agua total objetivo · 250 g a agregar'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
