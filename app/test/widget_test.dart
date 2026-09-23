import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_operator_assistant/main.dart';

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SmartOperatorApp()));
    await tester.pump();

    expect(find.text('Smart Operator'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Demo accounts'), findsOneWidget);
  });
}
