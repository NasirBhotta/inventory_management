import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_managment_sys/main.dart';

void main() {
  testWidgets('App renders initial loading state', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FertiTrackApp()));
    expect(find.byType(FertiTrackApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
