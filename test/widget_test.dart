import 'package:flutter_test/flutter_test.dart';

import 'package:voicenote_leo/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceNoteApp());
    expect(find.text('Fundação do projeto — telas em construção'), findsOneWidget);
  });
}
