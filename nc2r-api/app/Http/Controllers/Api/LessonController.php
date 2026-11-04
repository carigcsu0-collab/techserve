<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Lesson;
use Illuminate\Http\Request;

class LessonController extends Controller
{
    /**
     * Return all lessons ordered by order_index with gated progression.
     *
     * A lesson is unlocked if it is the first in sequence or the user has
     * completed the previous lesson. media_url is hidden while locked.
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $isAdmin = $user->isAdmin();

        $completedIds = $user->progress()
            ->where('is_completed', true)
            ->pluck('lesson_id')
            ->flip();

        $previousCompleted = true; // first lesson in sequence is always unlocked

        $lessons = Lesson::orderBy('order_index')->get()->map(function (Lesson $lesson) use ($completedIds, &$previousCompleted, $isAdmin) {
            $isUnlocked = $isAdmin || $previousCompleted;
            $isCompleted = $completedIds->has($lesson->id);
            $previousCompleted = $isCompleted;

            return [
                'id' => $lesson->id,
                'title' => $lesson->title,
                'description' => $lesson->description,
                'media_url' => $isUnlocked ? $lesson->media_url : null,
                'media_type' => $lesson->media_type,
                'order_index' => $lesson->order_index,
                'is_unlocked' => $isUnlocked,
                'is_completed' => $isCompleted,
            ];
        });

        return response()->json(['lessons' => $lessons]);
    }
}
