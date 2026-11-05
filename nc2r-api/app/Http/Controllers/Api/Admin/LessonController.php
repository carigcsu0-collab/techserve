<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Jobs\TranscodeLessonVideo;
use App\Models\AdminAuditLog;
use App\Models\Lesson;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class LessonController extends Controller
{
    private const MAX_VIDEO_KB = 2097152; // 2 GB
    private const MAX_IMAGE_KB = 51200;   // 50 MB

    // Any common video container. Playback still depends on the device's codecs.
    private const VIDEO_EXTENSIONS = [
        'mp4', 'm4v', 'mov', 'webm', 'mkv', 'avi', 'wmv', 'flv', 'f4v', 'mpeg', 'mpg',
        'mpe', 'm2v', 'ts', 'm2ts', 'mts', '3gp', '3g2', 'ogv', 'vob', 'asf', 'rm', 'rmvb', 'divx',
    ];

    private const IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

    private function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'media_type' => ['required', Rule::in(['video', 'image'])],
            'order_index' => ['required', 'integer', 'min:1'],
            'media_url' => ['required_without:media_file', 'nullable', 'string', 'max:2048'],
            'media_file' => array_merge(['required_without:media_url'], $this->mediaFileRules()),
        ];
    }

    private function mediaFileRules(): array
    {
        $extensions = array_merge(self::VIDEO_EXTENSIONS, self::IMAGE_EXTENSIONS);

        return [
            'file',
            'mimes:' . implode(',', $extensions),
            'max:' . self::MAX_VIDEO_KB,
        ];
    }

    // Laravel's max rule only knows one limit, so images get a stricter check here.
    private function validateLesson(Request $request, array $rules, string $mediaType): array
    {
        $validator = Validator::make($request->all(), $rules);

        $validator->after(function ($v) use ($request, $mediaType) {
            $file = $request->file('media_file');
            if ($file && $mediaType === 'image' && $file->getSize() > self::MAX_IMAGE_KB * 1024) {
                $v->errors()->add('media_file', 'Images must be 50 MB or smaller.');
            }
        });

        return $validator->validate();
    }

    public function store(Request $request)
    {
        $validated = $this->validateLesson($request, array_merge($this->rules(), [
            'order_index' => ['required', 'integer', 'min:1', 'unique:lessons,order_index'],
        ]), (string) $request->input('media_type'));

        if ($request->hasFile('media_file')) {
            $validated['media_url'] = $this->storeMedia($request);
        }
        unset($validated['media_file']);

        $lesson = Lesson::create($validated);
        $this->queueVideoTranscode($lesson, $request);
        AdminAuditLog::record($request->user(), 'lesson.created', "Created lesson \"{$lesson->title}\"", $lesson);

        return response()->json(['lesson' => $lesson], 201);
    }

    public function update(Request $request, Lesson $lesson)
    {
        $rules = collect($this->rules())->map(function ($rule) {
            $rule[0] = 'sometimes';
            return $rule;
        })->all();

        $rules['media_url'] = ['nullable', 'string', 'max:2048'];
        $rules['media_file'] = array_merge(['nullable'], $this->mediaFileRules());
        $rules['order_index'] = [
            'sometimes', 'integer', 'min:1',
            Rule::unique('lessons', 'order_index')->ignore($lesson->id),
        ];

        $validated = $this->validateLesson(
            $request,
            $rules,
            (string) $request->input('media_type', $lesson->media_type)
        );

        if ($request->hasFile('media_file')) {
            $this->deleteMedia($lesson);
            $validated['media_url'] = $this->storeMedia($request);
        }
        unset($validated['media_file']);

        $lesson->update($validated);
        $this->queueVideoTranscode($lesson, $request);
        AdminAuditLog::record($request->user(), 'lesson.updated', "Updated lesson \"{$lesson->title}\"", $lesson);

        return response()->json(['lesson' => $lesson->fresh()]);
    }

    public function publish(Request $request, Lesson $lesson)
    {
        $validated = $request->validate([
            'is_published' => ['required', 'boolean'],
        ]);

        if ($lesson->is_published !== $validated['is_published']) {
            $lesson->update(['is_published' => $validated['is_published']]);

            AdminAuditLog::record(
                $request->user(),
                $lesson->is_published ? 'lesson.published' : 'lesson.unpublished',
                ($lesson->is_published ? 'Published' : 'Unpublished') . " lesson \"{$lesson->title}\"",
                $lesson,
            );
        }

        return response()->json(['lesson' => $lesson->fresh()]);
    }

    // Two-phase write so the unique order_index never collides mid-update.
    public function reorder(Request $request)
    {
        $validated = $request->validate([
            'ids' => ['required', 'array', 'min:1'],
            'ids.*' => ['integer', 'distinct'],
        ]);

        $ids = $validated['ids'];
        $existing = Lesson::query()->pluck('id')->all();

        if (count($ids) !== count($existing) || array_diff($existing, $ids) !== []) {
            return response()->json(['message' => 'Provide every lesson id exactly once.'], 422);
        }

        DB::transaction(function () use ($ids) {
            foreach ($ids as $position => $id) {
                Lesson::whereKey($id)->update(['order_index' => -($position + 1)]);
            }
            foreach ($ids as $position => $id) {
                Lesson::whereKey($id)->update(['order_index' => $position + 1]);
            }
        });

        AdminAuditLog::record($request->user(), 'lesson.reordered', 'Reordered ' . count($ids) . ' lessons');

        return response()->json(['message' => 'Lessons reordered']);
    }

    // The upload is saved as-is right away; the queue worker converts it to MP4 afterwards.
    private function queueVideoTranscode(Lesson $lesson, Request $request): void
    {
        if ($lesson->media_type === 'video' && $request->hasFile('media_file')) {
            TranscodeLessonVideo::dispatch($lesson->id);
        }
    }

    public function destroy(Request $request, Lesson $lesson)
    {
        $title = $lesson->title;

        $this->deleteMedia($lesson);
        $lesson->delete();
        AdminAuditLog::record($request->user(), 'lesson.deleted', "Deleted lesson \"{$title}\"");

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
