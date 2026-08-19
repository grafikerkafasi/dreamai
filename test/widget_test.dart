import 'package:flutter_test/flutter_test.dart';
import 'package:dream_ai/openai_service.dart';

void main() {
  test('uses a local demo analysis by default', () async {
    final result = await OpenAIService.analyzeDream('A calm dream', 'Jung');

    expect(result, contains('local demo analysis'));
  });

  test('exposes configured interpreters', () {
    expect(OpenAIService.getAvailableInterpreters(), contains('Jung'));
  });
}
