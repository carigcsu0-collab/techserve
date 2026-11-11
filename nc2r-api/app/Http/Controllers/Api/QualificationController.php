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
            ->with('lessons')
            ->orderBy('order_index')
            ->get()
            ->map(function (Qualification $qualification) use ($completedIds) {
                $lessons = $qualification->lessons;
                $completed = $lessons->filter(fn (Lesson $lesson) => $completedIds->has($lesson->id))->count();
                $total = $lessons->count();

                return [
                    'id' => $qualification->id,
                    'title' => $qualification->title,
                    'description' => $qualification->description,
                    'order_index' => $qualification->order_index,
                    'lesson_count' => $total,
                    'completed_count' => $completed,
                    'progress' => $total > 0 ? round($completed / $total, 4) : 0.0,
                    'is_completed' => $total > 0 && $completed === $total,
                ];
            });

        return response()->json(['qualifications' => $qualifications->values()]);
    }

    /**
     * One qualification with its lessons and the learner's lock state for each.
     */
    public function show(Request $request, Qualification $qualification)
    {
        $user = $request->user();

        $lessons = $qualification->lessons()->get();
        $presented = app(LessonProgress::class)->present($lessons, $user)->values();
        $allDone = $presented->isNotEmpty() && $presented->every(fn ($l) => $l['is_completed']);

        $examStatus = function (string $type) use ($qualification, $user) {
            $exam = $qualification->activeExam($type);
            if ($exam === null) {
                return null;
            }
            $attempts = $exam->attempts()->where('user_id', $user->id);
            $best = (clone $attempts)->max('score');

            return [
                'id' => $exam->id,
                'items' => $exam->itemsFor($exam->questions()->count()),
                'passing_score' => $exam->passing_score,
                'taken' => $attempts->exists(),
                'passed' => (clone $attempts)->where('passed', true)->exists(),
                'best_score' => $best,
            ];
        };

        $pre = $examStatus('pre');
        $post = $examStatus('post');
        if ($post !== null) {
            $post['available'] = $user->isAdmin() || ($allDone && !($pre !== null && !$pre['taken']));
        }

        return response()->json([
            'qualification' => [
                'id' => $qualification->id,
                'title' => $qualification->title,
                'description' => $qualification->description,
            ],
            'lessons' => $presented,
            'exams' => ['pre' => $pre, 'post' => $post],
        ]);
    }
}
