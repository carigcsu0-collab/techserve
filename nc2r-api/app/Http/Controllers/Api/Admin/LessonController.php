<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Lesson;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class LessonController extends Controller
{
    private function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'media_type' => ['required', Rule::in(['video', 'image'])],
            'order_index' => ['required', 'integer', 'min:1'],
            'media_url' => ['required_without:media_file', 'nullable', 'string', 'max:2048'],
            'media_file' => [
                'required_without:media_url',
                'file',
                'mimetypes:video/mp4,video/webm,video/quicktime,image/jpeg,image/png,image/gif,image/webp',
                'max:51200',
            ],
        ];
    }

    public function store(Request $request)
    {
        $validated = $request->validate(array_merge($this->rules(), [
            'order_index' => ['required', 'integer', 'min:1', 'unique:lessons,order_index'],
        ]));

        if ($request->hasFile('media_file')) {
            $validated['media_url'] = $this->storeMedia($request);
        }
        unset($validated['media_file']);

        $lesson = Lesson::create($validated);

        return response()->json(['lesson' => $lesson], 201);
    }

    public function update(Request $request, Lesson $lesson)
    {
        $rules = collect($this->rules())->map(function ($rule) {
            $rule[0] = 'sometimes';
            return $rule;
        })->all();

        $rules['media_url'] = ['nullable', 'string', 'max:2048'];
        $rules['media_file'] = [
            'nullable', 'file',
            'mimetypes:video/mp4,video/webm,video/quicktime,image/jpeg,image/png,image/gif,image/webp',
            'max:51200',
        ];
        $rules['order_index'] = [
            'sometimes', 'integer', 'min:1',
            Rule::unique('lessons', 'order_index')->ignore($lesson->id),
        ];

        $validated = $request->validate($rules);

        if ($request->hasFile('media_file')) {
            $this->deleteMedia($lesson);
            $validated['media_url'] = $this->storeMedia($request);
        }
        unset($validated['media_file']);

        $lesson->update($validated);

        return response()->json(['lesson' => $lesson->fresh()]);
    }

    public function destroy(Lesson $lesson)
    {
        $this->deleteMedia($lesson);
        $lesson->delete();

        return response()->json(['message' => 'Lesson deleted']);
    }

    private function storeMedia(Request $request): string
    {
        $path = $request->file('media_file')->store('lessons', 'public');

        return asset("storage/{$path}");
    }

    private function deleteMedia(Lesson $lesson): void
    {
        $path = parse_url((string) $lesson->media_url, PHP_URL_PATH) ?? '';

        if (str_starts_with($path, '/storage/lessons/')) {
            Storage::disk('public')->delete(substr($path, strlen('/storage/')));
        }
    }
}
