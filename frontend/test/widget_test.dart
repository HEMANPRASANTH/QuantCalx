import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const UltraProTradingApp());
    expect(find.byType(UltraProTradingApp), findsOneWidget);
  });
}
