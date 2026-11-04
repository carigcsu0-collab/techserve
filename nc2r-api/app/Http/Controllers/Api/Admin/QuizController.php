<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Lesson;
use App\Models\Quiz;
use App\Models\QuizSubmission;
use Illuminate\Http\Request;

class QuizController extends Controller
{
    /**
     * Create or update the quiz attached to a lesson (1:1).
     */
    public function store(Request $request, Lesson $lesson)
    {
        $validated = $request->validate([
            'passing_score' => ['required', 'integer', 'min:0', 'max:100'],
        ]);

        $quiz = Quiz::updateOrCreate(
            ['lesson_id' => $lesson->id],
            ['passing_score' => $validated['passing_score']]
        );

        return response()->json(['quiz' => $quiz->load('questions')], 201);
    }

    public function update(Request $request, Quiz $quiz)
    {
        $validated = $request->validate([
            'passing_score' => ['required', 'integer', 'min:0', 'max:100'],
        ]);

        $quiz->update($validated);

        return response()->json(['quiz' => $quiz->load('questions')]);
    }

    public function destroy(Quiz $quiz)
    {
        $quiz->delete();

        return response()->json(['message' => 'Quiz deleted']);
    }

    /**
     * List learner submissions for a quiz, with a per-question breakdown
     * showing each submitted answer, the correct answer, and whether it
     * was marked correct.
     */
    public function submissions(Quiz $quiz)
    {
        $questions = $quiz->questions;

        $submissions = QuizSubmission::where('quiz_id', $quiz->id)
            ->with('user:id,name,email')
            ->latest()
            ->get()
            ->map(function (QuizSubmission $submission) use ($questions) {
                return [
                    'id' => $submission->id,
                    'user' => $submission->user,
                    'score' => $submission->score,
                    'passed' => $submission->passed,
                    'created_at' => $submission->created_at,
                    'answers' => $questions->map(function ($question) use ($submission) {
                        $answer = $submission->answers[$question->id] ?? null;

                        return [
                            'question_id' => $question->id,
                            'question_text' => $question->question_text,
                            'question_type' => $question->question_type,
                            'options' => $question->options,
                            'submitted_answer' => $answer,
                            'correct_answer' => $question->correct_answer,
                            'is_correct' => $question->isCorrect($answer),
                        ];
                    })->values(),
                ];
            });

        return response()->json(['submissions' => $submissions]);
    }
}
