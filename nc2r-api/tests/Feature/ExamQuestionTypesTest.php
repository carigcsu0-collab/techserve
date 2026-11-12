<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\Qualification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ExamQuestionTypesTest extends TestCase
{
    use RefreshDatabase;

    private function user(string $role = 'user'): User
    {
        $user = User::create([
            'name' => 'Person',
            'email' => $role.'@x.com',
            'password' => bcrypt('password123'),
            'email_verified_at' => now(),
        ]);

        if ($role === 'admin') {
            $user->forceFill(['role' => 'admin'])->save();
        }

        return $user;
    }

    private function preExam(): Exam
    {
        $qualification = Qualification::create(['title' => 'Q', 'description' => 'D', 'order_index' => 1]);

        return Exam::create([
            'qualification_id' => $qualification->id,
            'type' => Exam::TYPE_PRE,
            'passing_score' => 50,
        ]);
    }

    public function test_bulk_import_stores_each_question_type(): void
    {
        Sanctum::actingAs($this->user('admin'));
        $exam = $this->preExam();

        $this->postJson("/api/admin/exams/{$exam->id}/questions/bulk", [
            'questions' => [
                ['question_type' => 'multiple_choice', 'question_text' => 'CPU?', 'options' => ['A', 'B'], 'correct_answer' => 'B'],
                ['question_type' => 'true_false', 'question_text' => 'Sky is blue.', 'correct_answer' => 'true'],
                ['question_type' => 'identification', 'question_text' => 'Capital of France?', 'correct_answer' => ' Paris '],
            ],
        ])->assertCreated();

        $questions = $exam->questions()->orderBy('id')->get();
        $this->assertSame(['multiple_choice', 'true_false', 'identification'], $questions->pluck('question_type')->all());
        $this->assertSame(['True', 'False'], $questions[1]->options);
        $this->assertSame('True', $questions[1]->correct_answer);
        $this->assertSame([], $questions[2]->options);
        $this->assertSame('Paris', $questions[2]->correct_answer);
    }

    public function test_invalid_questions_are_rejected(): void
    {
        Sanctum::actingAs($this->user('admin'));
        $exam = $this->preExam();

        $this->postJson("/api/admin/exams/{$exam->id}/questions/bulk", [
            'questions' => [
                ['question_type' => 'multiple_choice', 'question_text' => 'Bad', 'options' => ['A', 'B'], 'correct_answer' => 'C'],
            ],
        ])->assertUnprocessable();

        $this->postJson("/api/admin/exams/{$exam->id}/questions/bulk", [
            'questions' => [
                ['question_type' => 'true_false', 'question_text' => 'Maybe?', 'correct_answer' => 'Maybe'],
            ],
        ])->assertUnprocessable();

        $this->postJson("/api/admin/exams/{$exam->id}/questions", [
            'question_type' => 'identification',
            'question_text' => 'Blank answer',
            'correct_answer' => '  ',
        ])->assertUnprocessable();

        $this->assertSame(0, $exam->questions()->count());
    }

    public function test_learner_grades_each_type_and_never_sees_answers(): void
    {
        $exam = $this->preExam();
        $exam->questions()->createMany([
            ['question_text' => 'CPU?', 'question_type' => 'multiple_choice', 'options' => ['A', 'B'], 'correct_answer' => 'B'],
            ['question_text' => 'Sky?', 'question_type' => 'true_false', 'options' => ['True', 'False'], 'correct_answer' => 'True'],
            ['question_text' => 'Capital?', 'question_type' => 'identification', 'options' => [], 'correct_answer' => 'Paris'],
        ]);

        Sanctum::actingAs($this->user());
        $paper = $this->getJson("/api/qualifications/{$exam->qualification_id}/exams/pre")
            ->assertOk()
            ->json('exam.questions');

        $this->assertArrayNotHasKey('correct_answer', $paper[0]);
        $byType = collect($paper)->keyBy('question_type');
        $this->assertSame([], $byType['identification']['options']);

        $answers = [];
        foreach ($exam->questions()->get() as $q) {
            $answers[$q->id] = match ($q->question_type) {
                'identification' => ' paris ',
                'true_false' => 'False',
                default => 'B',
            };
        }

        $result = $this->postJson("/api/exams/{$exam->id}/submit", ['answers' => $answers])
            ->assertOk()
            ->json();

        $this->assertSame(2, $result['correct']);
        $this->assertSame(3, $result['total']);
    }
}
