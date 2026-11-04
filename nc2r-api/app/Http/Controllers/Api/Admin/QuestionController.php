<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Question;
use App\Models\Quiz;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class QuestionController extends Controller
{
    public function store(Request $request, Quiz $quiz)
    {
        $validated = $request->validate($this->rules($request));

        $question = $quiz->questions()->create($validated);

        return response()->json(['question' => $question], 201);
    }

    public function update(Request $request, Question $question)
    {
        $validated = $request->validate($this->rules($request));

        $question->update($validated);

        return response()->json(['question' => $question->fresh()]);
    }

    public function destroy(Question $question)
    {
        $question->delete();

        return response()->json(['message' => 'Question deleted']);
    }

    private function rules(Request $request): array
    {
        $isIdentification = $request->input('question_type') === 'identification';
        $options = $request->input('options');

        return [
            'question_text' => ['required', 'string'],
            'question_type' => [
                'required',
                Rule::in(['multiple_choice', 'true_false', 'identification']),
            ],
            'options' => $isIdentification
                ? ['nullable', 'array']
                : ['required', 'array', 'min:2'],
            'options.*' => ['string', 'max:255'],
            'correct_answer' => array_merge(
                ['required', 'string', 'max:255'],
                (!$isIdentification && is_array($options))
                    ? [Rule::in($options)]
                    : []
            ),
        ];
    }
}
