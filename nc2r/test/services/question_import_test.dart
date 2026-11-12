import 'package:flutter_test/flutter_test.dart';
import 'package:nc2r/services/question_import.dart';

void main() {
  group('text blocks', () {
    test('parses multiple choice, true/false and identification', () {
      final result = parseQuestionImport('''
What does CPU stand for?
*Central Processing Unit
Central Program Unit

TF: The sky is blue.
Answer: true

ID: Capital of France?
Answer: Paris
''');

      expect(result, hasLength(3));
      expect(result[0], {
        'question_type': 'multiple_choice',
        'question_text': 'What does CPU stand for?',
        'options': ['Central Processing Unit', 'Central Program Unit'],
        'correct_answer': 'Central Processing Unit',
      });
      expect(result[1], {
        'question_type': 'true_false',
        'question_text': 'The sky is blue.',
        'options': ['True', 'False'],
        'correct_answer': 'True',
      });
      expect(result[2], {
        'question_type': 'identification',
        'question_text': 'Capital of France?',
        'options': <String>[],
        'correct_answer': 'Paris',
      });
    });

    test('rejects a multiple choice question without a * answer', () {
      expect(
        () => parseQuestionImport('Q?\nA\nB'),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('correct answer'))),
      );
    });

    test('rejects true/false without an Answer line', () {
      expect(
        () => parseQuestionImport('TF: Sky?'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('True or False'))),
      );
    });
  });

  group('csv', () {
    test('parses rows with quoted cells and short type names', () {
      final result = parseQuestionImport('''
type,question,options,answer
mc,"Largest planet, by size?",Mars|Jupiter|Venus,Jupiter
tf,The sun orbits the earth.,,False
identification,"Who wrote ""Noli""?",,Rizal
''');

      expect(result, hasLength(3));
      expect(result[0]['question_text'], 'Largest planet, by size?');
      expect(result[0]['options'], ['Mars', 'Jupiter', 'Venus']);
      expect(result[0]['correct_answer'], 'Jupiter');
      expect(result[1]['question_type'], 'true_false');
      expect(result[1]['correct_answer'], 'False');
      expect(result[2]['question_text'], 'Who wrote "Noli"?');
      expect(result[2]['options'], <String>[]);
      expect(result[2]['correct_answer'], 'Rizal');
    });

    test('rejects a missing header column', () {
      expect(
        () => parseQuestionImport('type,question,answer\nmc,Q,A'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('header'))),
      );
    });

    test('rejects an unknown type with its row number', () {
      expect(
        () => parseQuestionImport(
            'type,question,options,answer\nessay,Explain it,,x'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Row 2'))),
      );
    });

    test('rejects a multiple choice answer that is not an option', () {
      expect(
        () => parseQuestionImport(
            'type,question,options,answer\nmc,Q?,A|B,C'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('empty input is rejected', () {
    expect(() => parseQuestionImport('  \n '), throwsFormatException);
  });
}
