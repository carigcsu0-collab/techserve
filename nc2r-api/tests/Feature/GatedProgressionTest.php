<?php

namespace Tests\Feature;

use App\Models\Lesson;
use App\Models\Quiz;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class GatedProgressionTest extends TestCase
{
    use RefreshDatabase;

    private function seedCourse(): array
    {
        $lessonOne = Lesson::factory()->create(['order_index' => 1, 'media_url' => 'https://example.com/one.mp4']);
        $lessonTwo = Lesson::factory()->create(['order_index' => 2, 'media_url' => 'https://example.com/two.mp4']);

        $quizOne = Quiz::factory()->for($lessonOne)->create(['passing_score' => 70]);
        $quizOne->questions()->createMany([
            ['question_text' => 'Q1', 'options' => ['a', 'b'], 'correct_answer' => 'a'],
            ['question_text' => 'Q2', 'options' => ['a', 'b'], 'correct_answer' => 'b'],
            ['question_text' => 'Q3', 'question_type' => 'identification', 'options' => null, 'correct_answer' => 'NTFS'],
        ]);

        $quizTwo = Quiz::factory()->for($lessonTwo)->create(['passing_score' => 70]);
        $quizTwo->questions()->createMany([
            ['question_text' => 'Q3', 'options' => ['a', 'b'], 'correct_answer' => 'a'],
        ]);

        return [$lessonOne, $lessonTwo, $quizOne, $quizTwo];
    }

    public function test_lessons_endpoint_requires_authentication(): void
    {
        $this->getJson('/api/lessons')->assertUnauthorized();
    }

    public function test_first_lesson_unlocked_rest_locked_with_media_hidden(): void
    {
        [$lessonOne, $lessonTwo] = $this->seedCourse();
        Sanctum::actingAs(User::factory()->create());

        $lessons = $this->getJson('/api/lessons')->assertOk()->json('lessons');

        $this->assertTrue($lessons[0]['is_unlocked']);
        $this->assertSame('https://example.com/one.mp4', $lessons[0]['media_url']);

        $this->assertFalse($lessons[1]['is_unlocked']);
        $this->assertNull($lessons[1]['media_url']);
    }

    public function test_passing_quiz_completes_lesson_and_unlocks_next(): void
    {
        [$lessonOne, $lessonTwo, $quizOne] = $this->seedCourse();
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $answers = $quizOne->questions->mapWithKeys(
            fn ($q) => [$q->id => $q->correct_answer]
        );

        $this->postJson("/api/quizzes/{$quizOne->id}/submit", ['answers' => $answers])
            ->assertOk()
            ->assertJson(['score' => 100, 'passed' => true, 'next_lesson_unlocked' => true]);

        $this->assertDatabaseHas('user_progress', [
            'user_id' => $user->id,
            'lesson_id' => $lessonOne->id,
            'is_completed' => true,
            'score' => 100,
        ]);

        $lessons = $this->getJson('/api/lessons')->json('lessons');
        $this->assertTrue($lessons[1]['is_unlocked']);
        $this->assertSame('https://example.com/two.mp4', $lessons[1]['media_url']);
    }

    public function test_failing_quiz_does_not_complete_lesson(): void
    {
        [$lessonOne, $lessonTwo, $quizOne] = $this->seedCourse();
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $answers = $quizOne->questions->mapWithKeys(fn ($q) => [$q->id => 'wrong']);

        $this->postJson("/api/quizzes/{$quizOne->id}/submit", ['answers' => $answers])
            ->assertOk()
            ->assertJson(['score' => 0, 'passed' => false, 'next_lesson_unlocked' => false]);

        $this->assertDatabaseMissing('user_progress', [
            'user_id' => $user->id,
            'lesson_id' => $lessonOne->id,
            'is_completed' => true,
        ]);
    }

    public function test_quiz_show_blocks_locked_lessons_and_hides_answers(): void
    {
        [$lessonOne, $lessonTwo, $quizOne] = $this->seedCourse();
        Sanctum::actingAs(User::factory()->create());

        // Locked lesson's quiz is forbidden
        $this->getJson("/api/lessons/{$lessonTwo->id}/quiz")->assertForbidden();

        // Unlocked lesson's quiz returns questions without correct answers
        $response = $this->getJson("/api/lessons/{$lessonOne->id}/quiz")->assertOk();
        $this->assertArrayNotHasKey('correct_answer', $response->json('quiz.questions.0'));
        $this->assertCount(3, $response->json('quiz.questions'));
        $this->assertSame('identification', $response->json('quiz.questions.2.question_type'));
    }

    public function test_identification_answers_are_graded_case_insensitively(): void
    {
        [$lessonOne, $lessonTwo, $quizOne] = $this->seedCourse();
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // 2/3 correct: one MC right, one MC wrong, identification right with odd casing/whitespace
        $answers = $quizOne->questions->mapWithKeys(fn ($q) => [
            $q->id => match ($q->question_text) {
                'Q1' => 'a',
                'Q2' => 'wrong',
                'Q3' => '  ntfs  ',
            },
        ]);

        $this->postJson("/api/quizzes/{$quizOne->id}/submit", ['answers' => $answers])
            ->assertOk()
            ->assertJson(['score' => 67, 'passed' => false]);
    }

    public function test_completing_all_lessons_issues_certificate(): void
    {
        Storage::fake('public');
        [$lessonOne, $lessonTwo, $quizOne, $quizTwo] = $this->seedCourse();
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $allCorrect = fn ($quiz) => $quiz->questions->mapWithKeys(fn ($q) => [$q->id => $q->correct_answer]);

        // First lesson passed — course not yet complete
        $this->postJson("/api/quizzes/{$quizOne->id}/submit", ['answers' => $allCorrect($quizOne)])
            ->assertOk()
            ->assertJson(['passed' => true, 'course_completed' => false, 'certificate_url' => null]);

        // Final lesson passed — certificate generated
        $response = $this->postJson("/api/quizzes/{$quizTwo->id}/submit", ['answers' => $allCorrect($quizTwo)])
            ->assertOk()
            ->assertJson(['passed' => true, 'course_completed' => true]);

        $certificateUrl = $response->json('certificate_url');
        $this->assertNotNull($certificateUrl);
        $this->assertStringContainsString("certificates/certificate-{$user->id}.pdf", $certificateUrl);

        $this->assertTrue(Storage::disk('public')->exists("certificates/certificate-{$user->id}.pdf"));
        $this->assertSame($certificateUrl, $user->fresh()->certificate_url);
    }
}
