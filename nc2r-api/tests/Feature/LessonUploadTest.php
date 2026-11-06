<?php

namespace Tests\Feature;

use App\Models\Lesson;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LessonUploadTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_upload_a_video_lesson(): void
    {
        Storage::fake('public');
        Sanctum::actingAs(User::factory()->create(['role' => 'admin']));

        $this->post('/api/admin/lessons', [
            'title' => 'Intro',
            'description' => 'Video lesson',
            'media_type' => 'video',
            'order_index' => '1',
            'media_file' => UploadedFile::fake()->create('intro.mp4', 2048, 'video/mp4'),
        ], ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonPath('lesson.media_type', 'video');

        Storage::disk('public')->assertExists(Lesson::first()->media_url ? 'lessons/' . basename(Lesson::first()->media_url) : 'missing');
    }

    public function test_upload_reports_a_taken_order_index_clearly(): void
    {
        Storage::fake('public');
        Sanctum::actingAs(User::factory()->create(['role' => 'admin']));
        Lesson::factory()->create(['order_index' => 1]);

        $this->post('/api/admin/lessons', [
            'title' => 'Second',
            'description' => 'Video lesson',
            'media_type' => 'video',
            'order_index' => '1',
            'media_file' => UploadedFile::fake()->create('second.mp4', 2048, 'video/mp4'),
        ], ['Accept' => 'application/json'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('order_index');
    }
}
