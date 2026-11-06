import 'package:flutter_test/flutter_test.dart';
import 'package:nc2r/models/lesson.dart';

void main() {
  test('parses an admin create reply without learner progress fields', () {
    final lesson = Lesson.fromJson({
      'id': 7,
      'title': 'Intro',
      'description': 'Welcome',
      'media_url': 'https://example.com/a.mp4',
      'media_type': 'video',
      'order_index': 3,
      'qualification_id': null,
      'is_published': true,
    });

    expect(lesson.id, 7);
    expect(lesson.orderIndex, 3);
    expect(lesson.isUnlocked, isFalse);
    expect(lesson.isCompleted, isFalse);
  });
}
