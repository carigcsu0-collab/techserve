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
        'is_published',
    ];

    protected function casts(): array
    {
        return [
            'order_index' => 'integer',
            'is_published' => 'boolean',
        ];
    }

    public function scopePublished($query)
    {
        return $query->where('is_published', true);
    }

    public function lessons(): HasMany
    {
        return $this->hasMany(Lesson::class)->orderBy('order_index');
    }
}
