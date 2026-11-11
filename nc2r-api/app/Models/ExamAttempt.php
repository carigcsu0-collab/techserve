<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ExamAttempt extends Model
{
    protected $fillable = [
        'user_id',
        'exam_id',
        'score',
        'passed',
        'correct',
        'total',
        'answers',
    ];

    protected function casts(): array
    {
        return [
            'score' => 'integer',
            'passed' => 'boolean',
            'correct' => 'integer',
            'total' => 'integer',
            'answers' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function exam(): BelongsTo
    {
        return $this->belongsTo(Exam::class);
    }
}
