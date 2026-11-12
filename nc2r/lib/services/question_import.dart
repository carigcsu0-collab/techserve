/// Parses admin-pasted or uploaded questions into the bulk-import payload.
///
/// Text blocks (blank line between questions):
///   What does CPU stand for?    <- multiple choice (default)
///   *Central Processing Unit    <- * marks the correct option
///   Central Program Unit
///
///   TF: The sky is blue.       <- true/false
///   Answer: True
///
///   ID: Capital of France?      <- identification (typed answer)
///   Answer: Paris
///
/// CSV (header row required, one question per line):
///   type,question,options,answer
///   multiple_choice,What does CPU stand for?,Central Processing Unit|Central Program Unit,Central Processing Unit
///   true_false,The sky is blue.,,True
///   identification,Capital of France?,,Paris
/// Options are separated by |. The type may also be mc, tf or id.
List<Map<String, dynamic>> parseQuestionImport(String raw) {
  final text = raw.replaceAll('\r', '').trim();
  if (text.isEmpty) throw const FormatException('Nothing to import.');

  final firstLine = text.split('\n').first.trim().toLowerCase();
  final questions = firstLine.startsWith('type,')
      ? _parseCsv(text)
      : _parseBlocks(text);
  if (questions.isEmpty) throw const FormatException('Nothing to import.');
  return questions;
}

const _multipleChoice = 'multiple_choice';
const _trueFalse = 'true_false';
const _identification = 'identification';

List<Map<String, dynamic>> _parseBlocks(String text) {
  final result = <Map<String, dynamic>>[];
  final blocks = text
      .split(RegExp(r'\n\s*\n'))
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty);

  var n = 0;
  for (final block in blocks) {
    n++;
    final lines = block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    var question = lines.first;
    var type = _multipleChoice;
    final tag = RegExp(r'^(TF|ID)\s*:\s*', caseSensitive: false)
        .firstMatch(question);
    if (tag != null) {
      type = tag.group(1)!.toUpperCase() == 'TF' ? _trueFalse : _identification;
      question = question.substring(tag.end).trim();
    }

    final options = <String>[];
    String? answer;
    for (final line in lines.skip(1)) {
      final answerLine = _answerLine(line);
      if (type != _multipleChoice) {
        if (answerLine == null) {
          throw FormatException(
              'Question $n: add an "Answer:" line after the question.');
        }
        answer = answerLine;
      } else if (line.startsWith('*')) {
        if (answer != null) {
          throw FormatException(
              'Question $n: only one option can be marked with *.');
        }
        final option = line.substring(1).trim();
        options.add(option);
        answer = option;
      } else {
        options.add(line);
      }
    }

    result.add(_build(n, type, question, options, answer));
  }
  return result;
}

List<Map<String, dynamic>> _parseCsv(String text) {
  final rows = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final header = _splitCsvLine(rows.first).map((h) => h.toLowerCase()).toList();
  final typeCol = header.indexOf('type');
  final questionCol = header.indexOf('question');
  final optionsCol = header.indexOf('options');
  final answerCol = header.indexOf('answer');
  if ([typeCol, questionCol, optionsCol, answerCol].contains(-1)) {
    throw const FormatException(
        'The CSV header must be: type,question,options,answer');
  }

  final result = <Map<String, dynamic>>[];
  for (var i = 1; i < rows.length; i++) {
    final cells = _splitCsvLine(rows[i]);
    String cell(int c) => c < cells.length ? cells[c] : '';

    final type = _csvType(i, cell(typeCol));
    final options = cell(optionsCol)
        .split('|')
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    result.add(_build(i, type, cell(questionCol), options, cell(answerCol)));
  }
  return result;
}

Map<String, dynamic> _build(
  int n,
  String type,
  String question,
  List<String> options,
  String? answer,
) {
  if (question.isEmpty) throw FormatException('Question $n has no text.');

  switch (type) {
    case _trueFalse:
      final match = ['True', 'False']
          .where((v) => v.toLowerCase() == (answer ?? '').toLowerCase())
          .toList();
      if (match.isEmpty) {
        throw FormatException('Question $n: the answer must be True or False.');
      }
      return {
        'question_type': type,
        'question_text': question,
        'options': ['True', 'False'],
        'correct_answer': match.first,
      };
    case _identification:
      if (answer == null || answer.isEmpty) {
        throw FormatException('Question $n needs an answer.');
      }
      return {
        'question_type': type,
        'question_text': question,
        'options': <String>[],
        'correct_answer': answer,
      };
    default:
      if (options.length < 2 || options.length > 8) {
        throw FormatException(
            'Question $n needs 2 to 8 options.');
      }
      if (answer == null || !options.contains(answer)) {
        throw FormatException(
            'Question $n: the correct answer must match one of the options.');
      }
      return {
        'question_type': _multipleChoice,
        'question_text': question,
        'options': options,
        'correct_answer': answer,
      };
  }
}

String? _answerLine(String line) {
  final match =
      RegExp(r'^answer\s*:\s*(.*)$', caseSensitive: false).firstMatch(line);
  return match?.group(1)?.trim();
}

String _csvType(int n, String value) {
  switch (value.trim().toLowerCase()) {
    case 'multiple_choice':
    case 'mc':
      return _multipleChoice;
    case 'true_false':
    case 'tf':
      return _trueFalse;
    case 'identification':
    case 'id':
      return _identification;
    default:
      throw FormatException(
          'Row ${n + 1}: unknown type "$value". Use multiple_choice, true_false or identification.');
  }
}

/// Splits one CSV line, honouring double-quoted cells and "" escapes.
List<String> _splitCsvLine(String line) {
  final cells = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        buffer.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      cells.add(buffer.toString().trim());
      buffer.clear();
    } else {
      buffer.write(c);
    }
  }
  cells.add(buffer.toString().trim());
  return cells;
}
