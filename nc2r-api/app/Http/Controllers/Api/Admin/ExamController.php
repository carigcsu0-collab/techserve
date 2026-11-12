<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Exam;
use App\Models\ExamQuestion;
use App\Models\Qualification;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ExamController extends Controller
{
    private const QUESTION_TYPES = [
        ExamQuestion::TYPE_MULTIPLE_CHOICE,
        ExamQuestion::TYPE_TRUE_FALSE,
        ExamQuestion::TYPE_IDENTIFICATION,
    ];

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
        $data = $this->prepare($request->validate($this->rules()), 'correct_answer');

        $exam->questions()->create($data);

        return response()->json(['exam' => $this->present($exam)], 201);
    }

    /**
     * Payload: { "questions": [ { question_type, question_text, options[], correct_answer }, ... ] }
     * question_type defaults to multiple_choice.
     */
    public function bulkStore(Request $request, Exam $exam)
    {
        $validated = $request->validate([
            'questions' => ['required', 'array', 'min:1', 'max:500'],
            'questions.*.question_type' => ['nullable', Rule::in(self::QUESTION_TYPES)],
            'questions.*.question_text' => ['required', 'string'],
            'questions.*.options' => ['nullable', 'array', 'max:8'],
            'questions.*.options.*' => ['nullable', 'string', 'max:255'],
            'questions.*.correct_answer' => ['required', 'string', 'max:255'],
        ]);

        $rows = [];
        foreach ($validated['questions'] as $i => $q) {
            $rows[] = $this->prepare($q, 'questions', $i + 1);
        }

        $exam->questions()->createMany($rows);

        return response()->json(['exam' => $this->present($exam)], 201);
    }

    public function updateQuestion(Request $request, ExamQuestion $question)
    {
        $data = $this->prepare($request->validate($this->rules()), 'correct_answer');

        $question->update($data);

        return response()->json(['exam' => $this->present($question->exam)]);
    }

    public function destroyQuestion(ExamQuestion $question)
    {
        $exam = $question->exam;
        $question->delete();

        return response()->json(['exam' => $this->present($exam)]);
    }

    private function rules(): array
    {
        return [
            'question_type' => ['nullable', Rule::in(self::QUESTION_TYPES)],
            'question_text' => ['required', 'string'],
            'options' => ['nullable', 'array', 'max:8'],
            'options.*' => ['nullable', 'string', 'max:255'],
            'correct_answer' => ['required', 'string', 'max:255'],
        ];
    }

    /**
     * Normalise one question for its type: true/false always has the fixed
     * True/False options, identification has none, and multiple choice needs
     * 2-8 options with the correct answer among them.
     */
    private function prepare(array $q, string $field, ?int $position = null): array
    {
        $type = $q['question_type'] ?? ExamQuestion::TYPE_MULTIPLE_CHOICE;
        $answer = trim($q['correct_answer']);
        $options = array_values(array_filter(
            array_map(fn ($o) => trim((string) $o), $q['options'] ?? []),
            fn ($o) => $o !== ''
        ));

        if ($type === ExamQuestion::TYPE_TRUE_FALSE) {
            $options = ['True', 'False'];
            $answer = collect($options)->first(fn ($o) => strcasecmp($o, $answer) === 0);
            $error = $answer === null ? 'the answer must be True or False.' : null;
        } elseif ($type === ExamQuestion::TYPE_IDENTIFICATION) {
            $options = [];
            $error = $answer === '' ? 'identification questions need an answer.' : null;
        } else {
            $error = match (true) {
                count($options) < 2 || count($options) > 8 => 'multiple choice questions need 2 to 8 options.',
                !in_array($answer, $options, true) => 'the correct answer must match one of the options.',
                default => null,
            };
        }

        if ($error !== null) {
            $prefix = $position === null ? '' : "Question {$position}: ";
            throw ValidationException::withMessages([$field => [$prefix.$error]]);
        }

        return [
            'question_text' => $q['question_text'],
            'question_type' => $type,
            'options' => $options,
            'correct_answer' => $answer,
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
                'question_type' => $q->question_type,
                'options' => $q->options,
                'correct_answer' => $q->correct_answer,
            ])->values(),
        ];
    }
}
