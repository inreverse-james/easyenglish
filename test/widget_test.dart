//widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easyenglish/pages/word_study_page.dart';

void main() {
  testWidgets('WordStudyPage displays word list', (WidgetTester tester) async {
    // word_study_page에 필요한 인자를 제공합니다.
    await tester.pumpWidget(
      const MaterialApp(
        home: WordStudyPage(
          level: 'beginner',
        ),
      ),
    );

    // Initial loading indicator check
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    // Check if the page displays the word and meaning
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('사과'), findsNothing); // Meaning is hidden initially
    expect(find.text('뜻 보기'), findsOneWidget);
  });
}
