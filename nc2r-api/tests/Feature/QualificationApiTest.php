<?php

namespace Tests\Feature;

use App\Models\Lesson;
use App\Models\Qualification;
use App\Models\User;
use App\Models\UserProgress;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class QualificationApiTest extends TestCase
{
    use RefreshDatabase;

    private function user(string $role = 'learner'): User
    {
        $user = User::create([
            'name' => ucfirst($role),
            'email' => "{$role}-" . uniqid() . '@x.com',
            'password' => bcrypt('password123'),
            'email_verified_at' => now(),
        ]);

        if ($role === 'admin') {
            $user->forceFill(['role' => 'admin'])->save();
        }

        return $user;
    }

    private function qualification(int $order, bool $published = true): Qualification
    {
        return Qualification::create([
            'title' => "Qualification {$order}",
            'description' => 'Course',
            'order_index' => $order,
            'is_published' => $published,
        ]);
    }

    private function lesson(Qualification $qualification, int $order): Lesson
    {
        return Lesson::create([
            'qualification_id' => $qualification->id,
            'title' => "Lesson {$order}",
            'description' => 'Body',
            'media_type' => 'image',
            'media_url' => "https://example.com/{$order}.png",
            'order_index' => $order,
            'is_published' => true,
        ]);
    }

    private function complete(User $user, Lesson $lesson): void
    {
        UserProgress::create([
            'user_id' => $user->id,
            'lesson_id' => $lesson->id,
            'is_completed' => true,
        ]);
    }

    public function test_learners_only_see_published_qualifications(): void
    {
        Sanctum::actingAs($this->user());
        $this->qualification(1);
        $this->qualification(2, false);

        $response = $this->getJson('/api/qualifications')->assertOk();

        $this->assertCount(1, $response->json('qualifications'));
        $this->assertArrayNotHasKey('is_published', $response->json('qualifications.0'));
    }

    public function test_draft_qualification_is_hidden_from_learners(): void
    {
        Sanctum::actingAs($this->user());
        $draft = $this->qualification(1, false);

        $this->getJson("/api/qualifications/{$draft->id}")->assertNotFound();
    }

    public function test_progression_is_scoped_to_each_qualification(): void
    {
        $user = $this->user();
        Sanctum::actingAs($user);

        $first = $this->qualification(1);
        $second = $this->qualification(2);
        $a1 = $this->lesson($first, 1);
        $a2 = $this->lesson($first, 2);
        $b1 = $this->lesson($second, 3);

        // Finishing the first qualification's opening lesson unlocks its second lesson
        // and must not lock or unlock anything in the other qualification.
        $this->complete($user, $a1);

        $unlocked = collect($this->getJson("/api/qualifications/{$first->id}")->json('lessons'))
            ->mapWithKeys(fn ($l) => [$l['id'] => $l['is_unlocked']]);
        $this->assertTrue($unlocked[$a2->id]);

        $other = collect($this->getJson("/api/qualifications/{$second->id}")->json('lessons'));
        $this->assertTrue($other->firstWhere('id', $b1->id)['is_unlocked']);
    }

    public function test_second_lesson_stays_locked_until_first_completed(): void
    {
        Sanctum::actingAs($this->user());

        $qualification = $this->qualification(1);
        $this->lesson($qualification, 1);
        $second = $this->lesson($qualification, 2);

        $lessons = collect($this->getJson("/api/qualifications/{$qualification->id}")->json('lessons'));
        $this->assertFalse($lessons->firstWhere('id', $second->id)['is_unlocked']);
    }

    public function test_qualification_progress_counts_completed_lessons(): void
    {
        $user = $this->user();
        Sanctum::actingAs($user);

        $qualification = $this->qualification(1);
        $first = $this->lesson($qualification, 1);
        $this->lesson($qualification, 2);
        $this->complete($user, $first);

        $item = collect($this->getJson('/api/qualifications')->json('qualifications'))->first();

        $this->assertSame(2, $item['lesson_count']);
        $this->assertSame(1, $item['completed_count']);
        $this->assertFalse($item['is_completed']);
    }

    public function test_admin_can_create_publish_and_delete_empty_qualification(): void
    {
        Sanctum::actingAs($this->user('admin'));

        $created = $this->postJson('/api/admin/qualifications', [
            'title' => 'Welding NC II',
            'description' => 'Course',
            'order_index' => 1,
        ])->assertCreated()->json('qualification');

        $this->putJson("/api/admin/qualifications/{$created['id']}", ['is_published' => false])
            ->assertOk()
            ->assertJsonPath('qualification.is_published', false);

        $this->deleteJson("/api/admin/qualifications/{$created['id']}")->assertOk();
    }

    public function test_qualification_can_be_created_without_order_index(): void
    {
        Sanctum::actingAs($this->user('admin'));

        Qualification::create(['title' => 'First', 'description' => 'A', 'order_index' => 4]);

        $created = $this->postJson('/api/admin/qualifications', [
            'title' => 'Second',
            'description' => 'B',
            'is_published' => true,
        ])->assertCreated()->json('qualification');

        $this->assertSame(5, $created['order_index']);
    }

    public function test_qualification_with_lessons_cannot_be_deleted(): void
    {
        Sanctum::actingAs($this->user('admin'));

        $qualification = $this->qualification(1);
        $this->lesson($qualification, 1);

        $this->deleteJson("/api/admin/qualifications/{$qualification->id}")->assertStatus(422);
        $this->assertDatabaseHas('qualifications', ['id' => $qualification->id]);
    }

    public function test_admin_reorders_lessons_within_one_qualification(): void
    {
        Sanctum::actingAs($this->user('admin'));

        $qualification = $this->qualification(1);
        $a = $this->lesson($qualification, 1);
        $b = $this->lesson($qualification, 2);
        $c = $this->lesson($qualification, 3);

        $this->putJson('/api/admin/lessons/reorder', [
            'qualification_id' => $qualification->id,
            'ids' => [$c->id, $a->id, $b->id],
        ])->assertOk();

        $this->assertSame([1, 2, 3], [
            Lesson::find($c->id)->order_index,
            Lesson::find($a->id)->order_index,
            Lesson::find($b->id)->order_index,
        ]);
    }

    public function test_reorder_rejects_lessons_from_another_qualification(): void
    {
        Sanctum::actingAs($this->user('admin'));

        $first = $this->qualification(1);
        $second = $this->qualification(2);
        $a = $this->lesson($first, 1);
        $this->lesson($first, 2);
        $other = $this->lesson($second, 3);

        $this->putJson('/api/admin/lessons/reorder', [
            'qualification_id' => $first->id,
            'ids' => [$a->id, $other->id],
        ])->assertStatus(422);
    }
}
