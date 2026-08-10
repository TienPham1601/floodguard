import 'package:flutter_test/flutter_test.dart';
import 'package:newcar/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FloodGuardApp());
    expect(find.text('FloodGuard'), findsOneWidget);
  });
}
