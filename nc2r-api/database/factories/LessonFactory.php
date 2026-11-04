<?php

namespace Database\Factories;

use App\Models\Lesson;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Lesson>
 */
class LessonFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'title' => fake()->sentence(4),
            'description' => fake()->paragraph(),
            'media_url' => fake()->url(),
            'media_type' => fake()->randomElement(['video', 'image']),
            'order_index' => fake()->unique()->numberBetween(1, 10000),
        ];
    }
}
