import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billing_mobile/main.dart';

void main() {
  testWidgets('Billing app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BillingApp()),
    );

    expect(find.text('Billing Pro'), findsOneWidget);
  });
}
