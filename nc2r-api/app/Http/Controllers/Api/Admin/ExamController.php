<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Exam;
use App\Models\ExamQuestion;
use App\Models\Qualification;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ExamController extends Controller
{
    /**
     * Pre-test and post-test of a qualification, with their full question
     * banks (including correct answers). Missing exams are created empty.
     */
    public function index(Qualification $qualification)
    {
        $exams = [];
        foreach ([Exam::TYPE_PRE, Exam::TYPE_POST] as $type) {
            $exam = Exam::firstOrCreate(
                ['qualification_id' => $qualification->id, 'type' => $type]
            );
            $exams[$type] = $this->present($exam);
        }

        return response()->json(['exams' => $exams]);
    }

    /**
     * Set passing score and how many items each learner receives.
     */
    public function update(Request $request, Exam $exam)
    {
        $validated = $request->validate([
            'passing_score' => ['required', 'integer', 'min:1', 'max:100'],
            'question_count' => ['nullable', 'integer', 'min:1', 'max:1000'],
        ]);

        $exam->update($validated);

        return response()->json(['exam' => $this->present($exam)]);
    }

    public function storeQuestion(Request $request, Exam $exam)
    {
        $validated = $request->validate($this->rules($request));

        $exam->questions()->create($validated);

        return response()->json(['exam' => $this->present($exam)], 201);
    }

    /**
     * Payload: { "questions": [ { question_text, options[], correct_answer }, ... ] }
     */
    public function bulkStore(Request $request, Exam $exam)
    {
        $validated = $request->validate([
            'questions' => ['required', 'array', 'min:1', 'max:500'],
            'questions.*.question_text' => ['required', 'string'],
            'questions.*.options' => ['required', 'array', 'min:2', 'max:8'],
            'questions.*.options.*' => ['required', 'string', 'max:255'],
            'questions.*.correct_answer' => ['required', 'string', 'max:255'],
        ]);

        foreach ($validated['questions'] as $i => $q) {
            abort_unless(
                in_array($q['correct_answer'], $q['options'], true),
                422,
                'Question '.($i + 1).': the correct answer must match one of the options.'
            );
        }

        $exam->questions()->createMany($validated['questions']);

        return response()->json(['exam' => $this->present($exam)], 201);
    }

    public function updateQuestion(Request $request, ExamQuestion $question)
    {
        $validated = $request->validate($this->rules($request));

        $question->update($validated);

        return response()->json(['exam' => $this->present($question->exam)]);
    }

    public function destroyQuestion(ExamQuestion $question)
    {
        $exam = $question->exam;
        $question->delete();

        return response()->json(['exam' => $this->present($exam)]);
    }

    private function rules(Request $request): array
    {
        $options = $request->input('options');

        return [
            'question_text' => ['required', 'string'],
            'options' => ['required', 'array', 'min:2', 'max:8'],
            'options.*' => ['required', 'string', 'max:255'],
            'correct_answer' => array_merge(
                ['required', 'string', 'max:255'],
                is_array($options) ? [Rule::in($options)] : []
            ),
        ];
    }

    private function present(Exam $exam): array
    {
        $questions = $exam->questions()->orderBy('id')->get();

        return [
            'id' => $exam->id,
            'qualification_id' => $exam->qualification_id,
            'type' => $exam->type,
            'passing_score' => $exam->passing_score,
            'question_count' => $exam->question_count,
            'bank_size' => $questions->count(),
            'questions' => $questions->map(fn ($q) => [
                'id' => $q->id,
                'question_text' => $q->question_text,
                'question_type' => 'multiple_choice',
                'options' => $q->options,
                'correct_answer' => $q->correct_answer,
            ])->values(),
        ];
    }
}
