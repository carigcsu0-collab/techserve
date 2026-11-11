<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Exam extends Model
{
    public const TYPE_PRE = 'pre';
    public const TYPE_POST = 'post';

    protected $fillable = [
        'qualification_id',
        'type',
        'passing_score',
        'question_count',
    ];

    protected function casts(): array
    {
        return [
            'passing_score' => 'integer',
            'question_count' => 'integer',
        ];
    }

    public function qualification(): BelongsTo
    {
        return $this->belongsTo(Qualification::class);
    }

    public function questions(): HasMany
    {
        return $this->hasMany(ExamQuestion::class);
    }

    public function attempts(): HasMany
    {
        return $this->hasMany(ExamAttempt::class);
    }

    /**
     * Number of questions a learner is given: the configured count capped
     * by the size of the question bank (all of them when no count is set).
     */
    public function itemsFor(int $bankSize): int
    {
        return $this->question_count === null || $this->question_count < 1
            ? $bankSize
            : min($this->question_count, $bankSize);
    }
}
