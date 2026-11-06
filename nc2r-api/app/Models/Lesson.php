<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
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
        'qualification_id',
    ];

    protected function casts(): array
    {
        return [
            'order_index' => 'integer',
            'qualification_id' => 'integer',
        ];
    }

    public function qualification(): BelongsTo
    {
        return $this->belongsTo(Qualification::class);
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
     * Lessons in the same qualification (or the same unassigned group).
     */
    public function scopeInSameQualification($query, ?int $qualificationId)
    {
        return $qualificationId === null
            ? $query->whereNull('qualification_id')
            : $query->where('qualification_id', $qualificationId);
    }

    /**
     * The lesson that must be completed before this one unlocks: the lesson
     * in the same qualification with the highest order_index below this one.
     */
    public function previous(): ?self
    {
        return static::query()
            ->inSameQualification($this->qualification_id)
            ->where('order_index', '<', $this->order_index)
            ->orderByDesc('order_index')
            ->first();
    }

    /**
     * The next lesson in the same qualification.
     */
    public function next(): ?self
    {
        return static::query()
            ->inSameQualification($this->qualification_id)
            ->where('order_index', '>', $this->order_index)
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
