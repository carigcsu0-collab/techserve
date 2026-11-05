<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminAuditLog extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = [
        'admin_id',
        'action',
        'subject_type',
        'subject_id',
        'summary',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }

    public function admin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'admin_id');
    }

    public static function record(User $admin, string $action, string $summary, ?Model $subject = null): void
    {
        static::create([
            'admin_id' => $admin->id,
            'action' => $action,
            'subject_type' => $subject ? class_basename($subject) : null,
            'subject_id' => $subject?->getKey(),
            'summary' => mb_substr($summary, 0, 255),
        ]);
    }

    public function toApi(): array
    {
        return [
            'id' => $this->id,
            'action' => $this->action,
            'summary' => $this->summary,
            'subject_type' => $this->subject_type,
            'subject_id' => $this->subject_id,
            'admin' => ['id' => $this->admin_id, 'name' => $this->admin?->name],
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
