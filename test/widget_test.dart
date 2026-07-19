import 'package:flutter_test/flutter_test.dart';

import 'package:voicenote_leo/main.dart';

void main() {
  testWidgets('Tela de gravação inicia no estado ocioso', (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceNoteApp());

    expect(find.text('NOTA DE VOZ'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(
      find.textContaining('Toque para gravar', findRichText: true),
      findsOneWidget,
    );
  });
}
