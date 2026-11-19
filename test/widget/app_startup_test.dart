import 'package:easy_hisab/app/easy_hisab_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts on role choice and opens each experience',
      (tester) async {
    await tester.pumpWidget(const EasyHisabApp());
    await tester.pumpAndSettle();

    expect(find.text('EasyHisab'), findsOneWidget);
    expect(find.text('I am a Shopkeeper'), findsOneWidget);
    expect(find.text('I am a Customer'), findsOneWidget);

    await tester.tap(find.text('I am a Shopkeeper'));
    await tester.pumpAndSettle();
    expect(find.text('My Shop'), findsOneWidget);

    await tester.tap(find.byTooltip('Change role'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I am a Customer'));
    await tester.pumpAndSettle();
    expect(find.text('My Shops'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
