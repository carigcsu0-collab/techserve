<?php

namespace Database\Factories;

use App\Models\Lesson;
use App\Models\User;
use App\Models\UserProgress;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<UserProgress>
 */
class UserProgressFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'lesson_id' => Lesson::factory(),
            'is_completed' => false,
            'score' => 0,
        ];
    }

    public function completed(int $score = 100): static
    {
        return $this->state(fn (array $attributes) => [
            'is_completed' => true,
            'score' => $score,
        ]);
    }
}
