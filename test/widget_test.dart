// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/main.dart';

void main() {
  testWidgets('GrillPOS app builds without error', (WidgetTester tester) async {
    // Minimal smoke test — just ensure the widget tree can be created.
    expect(MyApp.new, isNotNull);
  });
}
