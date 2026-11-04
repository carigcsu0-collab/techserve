<?php

namespace Database\Factories;

use App\Models\Question;
use App\Models\Quiz;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Question>
 */
class QuestionFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $options = [
            fake()->unique()->word(),
            fake()->unique()->word(),
            fake()->unique()->word(),
            fake()->unique()->word(),
        ];

        return [
            'quiz_id' => Quiz::factory(),
            'question_text' => fake()->sentence().'?',
            'question_type' => Question::TYPE_MULTIPLE_CHOICE,
            'options' => $options,
            'correct_answer' => fake()->randomElement($options),
        ];
    }

    public function identification(): static
    {
        return $this->state(fn (array $attributes) => [
            'question_type' => Question::TYPE_IDENTIFICATION,
            'options' => null,
            'correct_answer' => fake()->word(),
        ]);
    }

    public function trueFalse(): static
    {
        return $this->state(fn (array $attributes) => [
            'question_type' => Question::TYPE_TRUE_FALSE,
            'options' => ['True', 'False'],
            'correct_answer' => fake()->randomElement(['True', 'False']),
        ]);
    }
}
