import 'package:flutter_test/flutter_test.dart';

import 'package:medication_reminder/main.dart';

void main() {
  testWidgets('Onboarding renders headline and CTA', (WidgetTester tester) async {
    await tester.pumpWidget(const CertoApp());

    expect(find.textContaining('Your medication'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}
