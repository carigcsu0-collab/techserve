<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Qualification extends Model
{
    protected $fillable = [
        'title',
        'description',
        'order_index',
    ];

    protected function casts(): array
    {
        return [
            'order_index' => 'integer',
        ];
    }

    public function exams(): HasMany
    {
        return $this->hasMany(Exam::class);
    }

    /**
     * The pre-test or post-test, but only when it has questions to give.
     */
    public function activeExam(string $type): ?Exam
    {
        return $this->exams()
            ->where('type', $type)
            ->whereHas('questions')
            ->first();
    }

    /**
     * True while the learner still has to take this qualification's
     * pre-test before any lesson unlocks.
     */
    public function preTestPendingFor(User $user): bool
    {
        $exam = $this->activeExam(Exam::TYPE_PRE);

        return $exam !== null
            && !$exam->attempts()->where('user_id', $user->id)->exists();
    }

    public function lessons(): HasMany
    {
        return $this->hasMany(Lesson::class)->orderBy('order_index');
    }
}
