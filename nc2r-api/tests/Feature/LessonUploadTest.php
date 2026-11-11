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

    public function test_admin_can_upload_a_video_in_chunks(): void
    {
        Storage::fake('public');
        Sanctum::actingAs(User::factory()->create(['role' => 'admin']));

        $data = random_bytes(2500);
        $id = $this->postJson('/api/admin/uploads', ['name' => 'big.mp4', 'size' => strlen($data)])
            ->assertCreated()->json('upload_id');

        foreach ([[0, 1000], [1000, 1000], [2000, 500]] as [$offset, $length]) {
            $this->post("/api/admin/uploads/{$id}/chunk", [
                'offset' => $offset,
                'chunk' => UploadedFile::fake()->createWithContent('chunk', substr($data, $offset, $length)),
            ], ['Accept' => 'application/json'])->assertOk()->assertJsonPath('received', $offset + $length);
        }

        $this->postJson('/api/admin/lessons', [
            'title' => 'Big', 'description' => 'Chunked', 'media_type' => 'video',
            'order_index' => 1, 'upload_id' => $id,
        ])->assertCreated();

        $stored = 'lessons/' . basename(Lesson::first()->media_url);
        $this->assertSame($data, Storage::disk('public')->get($stored));
    }

    public function test_incomplete_chunked_upload_is_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'admin']));

        $id = $this->postJson('/api/admin/uploads', ['name' => 'big.mp4', 'size' => 5000])->json('upload_id');

        $this->postJson('/api/admin/lessons', [
            'title' => 'Big', 'description' => 'Chunked', 'media_type' => 'video',
            'order_index' => 1, 'upload_id' => $id,
        ])->assertStatus(422)->assertJsonValidationErrors('upload_id');
    }

    public function test_upload_session_belongs_to_its_creator(): void
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'admin']));
        $id = $this->postJson('/api/admin/uploads', ['name' => 'a.mp4', 'size' => 10])->json('upload_id');

        Sanctum::actingAs(User::factory()->create(['role' => 'admin']));
        $this->post("/api/admin/uploads/{$id}/chunk", [
            'offset' => 0,
            'chunk' => UploadedFile::fake()->createWithContent('chunk', 'abc'),
        ], ['Accept' => 'application/json'])->assertNotFound();
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
