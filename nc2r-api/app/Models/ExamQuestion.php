<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ExamQuestion extends Model
{
    public const TYPE_MULTIPLE_CHOICE = 'multiple_choice';
    public const TYPE_TRUE_FALSE = 'true_false';
    public const TYPE_IDENTIFICATION = 'identification';

    protected $fillable = [
        'exam_id',
        'question_text',
        'question_type',
        'options',
        'correct_answer',
    ];

    protected function casts(): array
    {
        return [
            'options' => 'array',
        ];
    }

    public function exam(): BelongsTo
    {
        return $this->belongsTo(Exam::class);
    }

    /**
     * Identification answers are graded case-insensitively and ignore
     * surrounding whitespace; choice types require an exact match.
     */
    public function isCorrect(?string $answer): bool
    {
        if ($answer === null) {
            return false;
        }

        if ($this->question_type === self::TYPE_IDENTIFICATION) {
            return mb_strtolower(trim($answer)) === mb_strtolower(trim($this->correct_answer));
        }

        return $answer === $this->correct_answer;
    }
}
