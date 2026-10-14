import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:svg_viewer/main.dart';

void main() {
  testWidgets('shows the SVG Viewer home screen', (tester) async {
    await tester.pumpWidget(const SvgViewerApp());
    expect(find.text('SVG Viewer'), findsOneWidget);
    expect(find.text('Abrir um SVG'), findsOneWidget);
    expect(find.text('Encontrar SVG no dispositivo'), findsOneWidget);
  });
}
