import 'package:flutter_test/flutter_test.dart';
import 'package:quantcalx/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const UltraProTradingApp());
    expect(find.byType(UltraProTradingApp), findsOneWidget);
  });
}
