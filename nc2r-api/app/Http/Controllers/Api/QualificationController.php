<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Lesson;
use App\Models\Qualification;
use App\Services\LessonProgress;
use Illuminate\Http\Request;

class QualificationController extends Controller
{
    /**
     * Qualifications (courses) with the learner's progress through each.
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $isAdmin = $user->isAdmin();

        $completedIds = $user->progress()
            ->where('is_completed', true)
            ->pluck('lesson_id')
            ->flip();

        $qualifications = Qualification::query()
            ->when(! $isAdmin, fn ($query) => $query->published())
            ->with(['lessons' => fn ($query) => $isAdmin ? $query : $query->published()])
            ->orderBy('order_index')
            ->get()
            ->map(function (Qualification $qualification) use ($completedIds, $isAdmin) {
                $lessons = $qualification->lessons;
                $completed = $lessons->filter(fn (Lesson $lesson) => $completedIds->has($lesson->id))->count();
                $total = $lessons->count();

                $data = [
                    'id' => $qualification->id,
                    'title' => $qualification->title,
                    'description' => $qualification->description,
                    'order_index' => $qualification->order_index,
                    'lesson_count' => $total,
                    'completed_count' => $completed,
                    'progress' => $total > 0 ? round($completed / $total, 4) : 0.0,
                    'is_completed' => $total > 0 && $completed === $total,
                ];

                if ($isAdmin) {
                    $data['is_published'] = $qualification->is_published;
                }

                return $data;
            });

        return response()->json(['qualifications' => $qualifications->values()]);
    }

    /**
     * One qualification with its lessons and the learner's lock state for each.
     */
    public function show(Request $request, Qualification $qualification)
    {
        $user = $request->user();

        if (! $qualification->is_published && ! $user->isAdmin()) {
            abort(404);
        }

        $lessons = $qualification->lessons()
            ->when(! $user->isAdmin(), fn ($query) => $query->published())
            ->get();

        return response()->json([
            'qualification' => [
                'id' => $qualification->id,
                'title' => $qualification->title,
                'description' => $qualification->description,
                'is_published' => $qualification->is_published,
            ],
            'lessons' => app(LessonProgress::class)->present($lessons, $user)->values(),
        ]);
    }
}
