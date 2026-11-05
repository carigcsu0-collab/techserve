<?php

namespace Tests\Feature;

use App\Models\Lesson;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PurgeLessonsTest extends TestCase
{
    use RefreshDatabase;

    public function test_purge_requires_force_flag(): void
    {
        Lesson::create([
            'title' => 'Intro',
            'description' => 'Hello',
            'media_type' => 'image',
            'media_url' => 'https://example.com/a.png',
            'order_index' => 1,
        ]);

        $this->artisan('lessons:purge')->assertFailed();

        $this->assertDatabaseCount('lessons', 1);
    }

    public function test_purge_with_force_deletes_all_lessons(): void
    {
        foreach (range(1, 3) as $i) {
            Lesson::create([
                'title' => "Lesson {$i}",
                'description' => 'Body',
                'media_type' => 'image',
                'media_url' => 'https://example.com/' . $i . '.png',
                'order_index' => $i,
            ]);
        }

        $this->artisan('lessons:purge', ['--force' => true])
            ->expectsOutput('Deleted 3 lesson(s).')
            ->assertSuccessful();

        $this->assertDatabaseCount('lessons', 0);
    }
}
