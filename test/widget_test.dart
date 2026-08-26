// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:proyectogrado/main.dart';

void main() {
  testWidgets('HMI renders and shows popup on button press', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('MAQUINA DOBLADORA AUTOMATICA'), findsOneWidget);
    expect(find.text('INICIAR'), findsOneWidget);
    expect(find.text('DETENER'), findsOneWidget);

    await tester.tap(find.text('INICIAR'));
    await tester.pumpAndSettle();

    expect(find.text('Accion detectada'), findsOneWidget);
    expect(find.text('Se presiono: Iniciar'), findsOneWidget);
  });
}
