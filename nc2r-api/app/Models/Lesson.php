<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Lesson extends Model
{
    /** @use HasFactory<\Database\Factories\LessonFactory> */
    use HasFactory;

    protected $fillable = [
        'title',
        'description',
        'media_url',
        'media_type',
        'order_index',
    ];

    protected function casts(): array
    {
        return [
            'order_index' => 'integer',
        ];
    }

    public function quiz(): HasOne
    {
        return $this->hasOne(Quiz::class);
    }

    public function userProgress(): HasMany
    {
        return $this->hasMany(UserProgress::class);
    }

    /**
     * The lesson that must be completed before this one unlocks,
     * i.e. the lesson with the highest order_index below this one.
     */
    public function previous(): ?self
    {
        return static::where('order_index', '<', $this->order_index)
            ->orderByDesc('order_index')
            ->first();
    }

    /**
     * The next lesson in sequence (highest order_index above this one).
     */
    public function next(): ?self
    {
        return static::where('order_index', '>', $this->order_index)
            ->orderBy('order_index')
            ->first();
    }

    /**
     * A lesson is unlocked when it is the first in sequence, or when the
     * user has completed the previous lesson.
     */
    public function isUnlockedFor(User $user): bool
    {
        $previous = $this->previous();

        if ($previous === null) {
            return true;
        }

        return $user->progress()
            ->where('lesson_id', $previous->id)
            ->where('is_completed', true)
            ->exists();
    }
}
