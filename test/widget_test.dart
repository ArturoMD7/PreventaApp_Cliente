import 'package:flutter_test/flutter_test.dart';

import 'package:preventa_app_cliente/main.dart';

void main() {
  testWidgets('App renders login screen for unauthenticated users',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('PreventaApp Cliente'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });
}
