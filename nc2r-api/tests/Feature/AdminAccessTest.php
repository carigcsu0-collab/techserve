<?php

namespace Tests\Feature;

use App\Models\Lesson;
use App\Models\Quiz;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminAccessTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['role' => 'admin']);
    }

    public function test_regular_users_cannot_access_admin_routes(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/admin/lessons', [
            'title' => 'X', 'description' => 'Y', 'media_type' => 'image',
            'order_index' => 9, 'media_url' => 'https://example.com/x.png',
        ])->assertForbidden();
    }

    public function test_admin_can_create_update_and_delete_lesson(): void
    {
        Sanctum::actingAs($this->admin());

        $lesson = $this->postJson('/api/admin/lessons', [
            'title' => 'New Lesson', 'description' => 'Desc',
            'media_type' => 'image', 'order_index' => 1,
            'media_url' => 'https://example.com/img.png',
        ])->assertCreated()->json('lesson');

        $this->putJson("/api/admin/lessons/{$lesson['id']}", [
            'title' => 'Renamed',
        ])->assertOk()->assertJsonPath('lesson.title', 'Renamed');

        $this->deleteJson("/api/admin/lessons/{$lesson['id']}")->assertOk();
        $this->assertDatabaseMissing('lessons', ['id' => $lesson['id']]);
    }

    public function test_admin_can_manage_quiz_and_questions(): void
    {
        Sanctum::actingAs($this->admin());
        $lesson = Lesson::factory()->create();

        $quiz = $this->postJson("/api/admin/lessons/{$lesson->id}/quiz", [
            'passing_score' => 80,
        ])->assertCreated()->json('quiz');

        $question = $this->postJson("/api/admin/quizzes/{$quiz['id']}/questions", [
            'question_text' => 'Pick one',
            'question_type' => 'multiple_choice',
            'options' => ['a', 'b'],
            'correct_answer' => 'b',
        ])->assertCreated()->json('question');

        // correct_answer must be one of the options
        $this->postJson("/api/admin/quizzes/{$quiz['id']}/questions", [
            'question_text' => 'Bad', 'question_type' => 'multiple_choice',
            'options' => ['a', 'b'], 'correct_answer' => 'zzz',
        ])->assertUnprocessable();

        $this->putJson("/api/admin/questions/{$question['id']}", [
            'question_text' => 'Updated', 'question_type' => 'identification',
            'options' => null, 'correct_answer' => 'free text',
        ])->assertOk();

        $this->deleteJson("/api/admin/questions/{$question['id']}")->assertOk();
        $this->deleteJson("/api/admin/quizzes/{$quiz['id']}")->assertOk();
    }

    public function test_admin_sees_all_lessons_unlocked_with_media(): void
    {
        $lessonTwo = Lesson::factory()->create(['order_index' => 2, 'media_url' => 'https://example.com/two.mp4']);
        Lesson::factory()->create(['order_index' => 1]);

        Sanctum::actingAs($this->admin());
        $lessons = $this->getJson('/api/lessons')->json('lessons');
        $this->assertTrue($lessons[1]['is_unlocked']);
        $this->assertSame('https://example.com/two.mp4', $lessons[1]['media_url']);
    }

    public function test_admin_quiz_response_includes_correct_answers(): void
    {
        $lesson = Lesson::factory()->create(['order_index' => 5]);
        $quiz = Quiz::factory()->for($lesson)->create();
        $quiz->questions()->create([
            'question_text' => 'Q', 'options' => ['a', 'b'], 'correct_answer' => 'a',
        ]);

        Sanctum::actingAs($this->admin());
        $this->getJson("/api/lessons/{$lesson->id}/quiz")
            ->assertOk()
            ->assertJsonPath('quiz.questions.0.correct_answer', 'a');
    }

    public function test_admin_can_review_submission_correct_and_wrong_answers(): void
    {
        $lesson = Lesson::factory()->create(['order_index' => 1]);
        $quiz = Quiz::factory()->for($lesson)->create(['passing_score' => 70]);
        $q1 = $quiz->questions()->create([
            'question_text' => 'Q1', 'question_type' => 'multiple_choice',
            'options' => ['a', 'b'], 'correct_answer' => 'a',
        ]);
        $q2 = $quiz->questions()->create([
            'question_text' => 'Q2', 'question_type' => 'identification',
            'options' => null, 'correct_answer' => 'NTFS',
        ]);

        $learner = User::factory()->create();
        Sanctum::actingAs($learner);
        $this->postJson("/api/quizzes/{$quiz->id}/submit", [
            'answers' => [$q1->id => 'a', $q2->id => 'wrong'],
        ])->assertOk();

        $this->assertDatabaseHas('quiz_submissions', [
            'user_id' => $learner->id, 'quiz_id' => $quiz->id,
            'score' => 50, 'passed' => false,
        ]);

        // Learners cannot read submissions.
        $this->getJson("/api/admin/quizzes/{$quiz->id}/submissions")->assertForbidden();

        Sanctum::actingAs($this->admin());
        $this->getJson("/api/admin/quizzes/{$quiz->id}/submissions")
            ->assertOk()
            ->assertJsonPath('submissions.0.user.id', $learner->id)
            ->assertJsonPath('submissions.0.score', 50)
            ->assertJsonPath('submissions.0.passed', false)
            ->assertJsonPath('submissions.0.answers.0.submitted_answer', 'a')
            ->assertJsonPath('submissions.0.answers.0.correct_answer', 'a')
            ->assertJsonPath('submissions.0.answers.0.is_correct', true)
            ->assertJsonPath('submissions.0.answers.1.submitted_answer', 'wrong')
            ->assertJsonPath('submissions.0.answers.1.correct_answer', 'NTFS')
            ->assertJsonPath('submissions.0.answers.1.is_correct', false);
    }
}
