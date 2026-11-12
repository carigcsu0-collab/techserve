<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Exam;
use App\Models\ExamQuestion;
use App\Models\Lesson;
use App\Models\Qualification;
use App\Models\UserProgress;
use App\Services\CertificateIssuer;
use Illuminate\Http\Request;

class ExamController extends Controller
{
    /**
     * Pre-test / post-test for a qualification: a fresh random selection of
     * questions in random order, with shuffled options. Correct answers are
     * never sent.
     */
    public function show(Request $request, Qualification $qualification, string $type)
    {
        abort_unless(in_array($type, [Exam::TYPE_PRE, Exam::TYPE_POST], true), 404);

        $user = $request->user();
        $exam = $qualification->activeExam($type);
        abort_if($exam === null, 404, 'This test has not been set up yet.');

        if ($type === Exam::TYPE_POST && !$user->isAdmin()) {
            abort_unless($this->lessonsDone($qualification, $user), 403, 'Finish all lessons to unlock the post-test.');
        }

        $bank = $exam->questions()->get();
        $questions = $bank->shuffle()->take($exam->itemsFor($bank->count()))->values();

        return response()->json([
            'exam' => [
                'id' => $exam->id,
                'qualification_id' => $qualification->id,
                'type' => $exam->type,
                'passing_score' => $exam->passing_score,
                'questions' => $questions->map(fn ($q) => [
                    'id' => $q->id,
                    'question_text' => $q->question_text,
                    'question_type' => $q->question_type,
                    'options' => $q->question_type === ExamQuestion::TYPE_IDENTIFICATION
                        ? []
                        : collect($q->options)->shuffle()->values(),
                ])->values(),
            ],
        ]);
    }

    /**
     * Payload: { "answers": { "<question_id>": "<answer>" } }. The score is
     * out of the number of items the exam is configured to deliver.
     */
    public function submit(Request $request, Exam $exam, CertificateIssuer $certificates)
    {
        $validated = $request->validate([
            'answers' => ['required', 'array'],
            'answers.*' => ['nullable', 'string'],
        ]);

        $user = $request->user();
        $qualification = $exam->qualification;

        if ($exam->type === Exam::TYPE_POST && !$user->isAdmin()) {
            abort_unless($this->lessonsDone($qualification, $user), 403, 'Finish all lessons to unlock the post-test.');
        }

        $bank = $exam->questions()->get()->keyBy('id');
        $total = $exam->itemsFor($bank->count());

        $correct = collect($validated['answers'])
            ->filter(fn ($answer, $id) => $bank->has((int) $id) && $bank[(int) $id]->isCorrect($answer))
            ->count();
        $correct = min($correct, $total);

        $score = $total > 0 ? (int) round($correct / $total * 100) : 0;
        $passed = $score >= $exam->passing_score;

        $exam->attempts()->create([
            'user_id' => $user->id,
            'score' => $score,
            'passed' => $passed,
            'correct' => $correct,
            'total' => $total,
            'answers' => $validated['answers'],
        ]);

        $certificateUrl = $user->certificate_url;
        if ($exam->type === Exam::TYPE_POST && $passed) {
            $certificateUrl = $certificates->issue($user);
        }

        return response()->json([
            'score' => $score,
            'correct' => $correct,
            'total' => $total,
            'passed' => $passed,
            'type' => $exam->type,
            'certificate_url' => $certificateUrl,
        ]);
    }

    /**
     * Mark a lesson as studied. Lessons no longer require a quiz.
     */
    public function completeLesson(Request $request, Lesson $lesson, CertificateIssuer $certificates)
    {
        $user = $request->user();

        abort_unless($user->isAdmin() || $lesson->isUnlockedFor($user), 403, 'This lesson is locked.');
        abort_if($lesson->quiz()->whereHas('questions')->exists(), 422, 'Pass the lesson quiz to complete this lesson.');

        UserProgress::updateOrCreate(
            ['user_id' => $user->id, 'lesson_id' => $lesson->id],
            ['is_completed' => true]
        );

        $qualification = $lesson->qualification;
        $certificateUrl = $user->certificate_url;

        // Without a post-test, finishing every lesson earns the certificate.
        if ($qualification !== null
            && $qualification->activeExam(Exam::TYPE_POST) === null
            && $this->lessonsDone($qualification, $user)) {
            $certificateUrl = $certificates->issue($user);
        }

        return response()->json([
            'completed' => true,
            'certificate_url' => $certificateUrl,
        ]);
    }

    private function lessonsDone(Qualification $qualification, $user): bool
    {
        $ids = $qualification->lessons()->pluck('id');

        return $ids->isNotEmpty()
            && $user->progress()->where('is_completed', true)->whereIn('lesson_id', $ids)->count() >= $ids->count()
            && !$qualification->preTestPendingFor($user);
    }
}
