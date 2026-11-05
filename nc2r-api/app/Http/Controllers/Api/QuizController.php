<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Lesson;
use App\Models\Quiz;
use App\Models\QuizSubmission;
use App\Models\User;
use App\Models\UserProgress;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class QuizController extends Controller
{
    /**
     * Return the quiz for a lesson. Locked lessons are rejected and
     * correct answers are never exposed to the client.
     */
    public function show(Request $request, Lesson $lesson)
    {
        $user = $request->user();

        abort_unless($user->isAdmin() || $lesson->is_published, 404);
        abort_unless($user->isAdmin() || $lesson->isUnlockedFor($user), 403, 'This lesson is locked.');

        $quiz = $lesson->quiz()->with('questions')->firstOrFail();
        $isAdmin = $user->isAdmin();

        return response()->json([
            'quiz' => [
                'id' => $quiz->id,
                'lesson_id' => $quiz->lesson_id,
                'passing_score' => $quiz->passing_score,
                'questions' => $quiz->questions->map(function ($question) use ($isAdmin) {
                    $data = [
                        'id' => $question->id,
                        'question_text' => $question->question_text,
                        'question_type' => $question->question_type,
                        'options' => $question->options,
                    ];
                    if ($isAdmin) {
                        $data['correct_answer'] = $question->correct_answer;
                    }

                    return $data;
                })->values(),
            ],
        ]);
    }

    /**
     * Grade a quiz submission, update progress on a pass, and issue a
     * certificate once every lesson in the course is completed.
     *
     * Payload: { "answers": { "<question_id>": "<answer>", ... } }
     */
    public function submit(Request $request, Quiz $quiz)
    {
        $validated = $request->validate([
            'answers' => ['required', 'array'],
            'answers.*' => ['nullable', 'string'],
        ]);

        $user = $request->user();
        abort_unless($user->isAdmin() || $quiz->lesson?->is_published, 404);
        $questions = $quiz->questions;
        $total = $questions->count();

        $correct = $questions->filter(
            fn ($question) => $question->isCorrect($validated['answers'][$question->id] ?? null)
        )->count();

        $score = $total > 0 ? (int) round($correct / $total * 100) : 0;
        $passed = $score >= $quiz->passing_score;

        QuizSubmission::create([
            'user_id' => $user->id,
            'quiz_id' => $quiz->id,
            'score' => $score,
            'passed' => $passed,
            'answers' => $validated['answers'],
        ]);

        if ($passed) {
            UserProgress::updateOrCreate(
                ['user_id' => $user->id, 'lesson_id' => $quiz->lesson_id],
                ['is_completed' => true, 'score' => $score]
            );
        }

        $courseCompleted = $this->hasCompletedCourse($user);

        if ($courseCompleted && $user->certificate_url === null) {
            $user->update(['certificate_url' => $this->generateCertificate($user)]);
        }

        $nextLesson = $quiz->lesson->next();
        $nextLessonUnlocked = $nextLesson !== null && $nextLesson->isUnlockedFor($user);

        return response()->json([
            'score' => $score,
            'passed' => $passed,
            'next_lesson_unlocked' => $nextLessonUnlocked,
            'course_completed' => $courseCompleted,
            'certificate_url' => $user->certificate_url,
        ]);
    }

    private function hasCompletedCourse(User $user): bool
    {
        $totalLessons = Lesson::count();

        return $totalLessons > 0 && $user->completedLessons()->count() >= $totalLessons;
    }

    private function generateCertificate(User $user): string
    {
        $path = "certificates/certificate-{$user->id}.pdf";

        $pdf = Pdf::loadView('certificate', [
            'name' => $user->name,
            'course' => 'NC II Reviewer — Computer Systems Servicing',
            'date' => now()->format('F d, Y'),
            'certificateId' => sprintf('NC2R-%06d-%s', $user->id, now()->format('Y')),
        ])->setPaper('a4', 'landscape');

        Storage::disk('public')->put($path, $pdf->output());

        return asset("storage/{$path}");
    }
}
