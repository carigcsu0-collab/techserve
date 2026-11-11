<?php

namespace App\Services;

use App\Models\Lesson;
use App\Models\Qualification;
use App\Models\User;
use Illuminate\Support\Collection;

class LessonProgress
{
    /**
     * Map lessons (already in display order) to learner-facing arrays.
     *
     * A lesson is unlocked when it is the first in its qualification or the
     * previous lesson in that same qualification is completed. Admins see
     * every lesson unlocked. media_url is hidden while locked.
     *
     * @param  Collection<int, Lesson>  $lessons
     * @return Collection<int, array<string, mixed>>
     */
    public function present(Collection $lessons, User $user): Collection
    {
        $isAdmin = $user->isAdmin();

        $completedIds = $user->progress()
            ->where('is_completed', true)
            ->pluck('lesson_id')
            ->flip();

        // Each qualification keeps its own sequence, so track the last result per group.
        $previousCompleted = [];

        $pending = [];
        $quizLessonIds = \App\Models\Quiz::whereHas('questions')->pluck('lesson_id')->flip();
        if (!$isAdmin) {
            foreach ($lessons->pluck('qualification_id')->filter()->unique() as $qualificationId) {
                $qualification = Qualification::find($qualificationId);
                $pending[$qualificationId] = $qualification?->preTestPendingFor($user) ?? false;
            }
        }

        return $lessons->map(function (Lesson $lesson) use ($completedIds, &$previousCompleted, $isAdmin, $pending, $quizLessonIds) {
            $group = $lesson->qualification_id ?? 0;
            $isUnlocked = $isAdmin
                || (!($pending[$lesson->qualification_id] ?? false) && ($previousCompleted[$group] ?? true));
            $isCompleted = $completedIds->has($lesson->id);
            $previousCompleted[$group] = $isCompleted;

            return [
                'id' => $lesson->id,
                'qualification_id' => $lesson->qualification_id,
                'title' => $lesson->title,
                'description' => $lesson->description,
                'media_url' => $isUnlocked ? $lesson->media_url : null,
                'media_type' => $lesson->media_type,
                'order_index' => $lesson->order_index,
                'is_unlocked' => $isUnlocked,
                'is_completed' => $isCompleted,
                'has_quiz' => $quizLessonIds->has($lesson->id),
            ];
        });
    }
}
