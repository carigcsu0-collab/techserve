<?php

namespace Tests\Feature;

use App\Models\AdminAuditLog;
use App\Models\Lesson;
use App\Models\Quiz;
use App\Models\QuizSubmission;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminApiTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        $user = User::create([
            'name' => 'Boss',
            'email' => 'boss@x.com',
            'password' => bcrypt('password123'),
            'email_verified_at' => now(),
        ]);

        // role is intentionally not mass-assignable.
        $user->forceFill(['role' => 'admin'])->save();

        return $user;
    }

    private function lesson(int $order): Lesson
    {
        return Lesson::create([
            'title' => "Lesson {$order}",
            'description' => 'Body',
            'media_type' => 'image',
            'media_url' => 'https://example.com/' . $order . '.png',
            'order_index' => $order,
        ]);
    }

    public function test_non_admin_cannot_reach_admin_endpoints(): void
    {
        Sanctum::actingAs(User::create([
            'name' => 'Learner',
            'email' => 'l@x.com',
            'password' => bcrypt('password123'),
            'email_verified_at' => now(),
        ]));

        $this->getJson('/api/admin/dashboard')->assertForbidden();
    }

    public function test_dashboard_returns_stats_and_recent_activity(): void
    {
        $admin = $this->admin();
        $this->lesson(1);
        $this->lesson(2);
        AdminAuditLog::record($admin, 'lesson.created', 'Created lesson');
        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/dashboard')
            ->assertOk()
            ->assertJsonPath('stats.lessons', 2)
            ->assertJsonPath('recent_activity.0.summary', 'Created lesson');
    }

    public function test_publish_route_is_removed(): void
    {
        $admin = $this->admin();
        $lesson = $this->lesson(1);
        Sanctum::actingAs($admin);

        $this->putJson("/api/admin/lessons/{$lesson->id}/publish", ['is_published' => true])
            ->assertNotFound();
    }

    public function test_reorder_swaps_positions_and_requires_every_id(): void
    {
        $admin = $this->admin();
        $first = $this->lesson(1);
        $second = $this->lesson(2);
        Sanctum::actingAs($admin);

        $this->putJson('/api/admin/lessons/reorder', ['ids' => [$second->id]])
            ->assertUnprocessable();

        $this->putJson('/api/admin/lessons/reorder', ['ids' => [$second->id, $first->id]])
            ->assertOk();

        $this->assertSame(1, $second->fresh()->order_index);
        $this->assertSame(2, $first->fresh()->order_index);
    }

    public function test_admin_cannot_remove_own_role(): void
    {
        $admin = $this->admin();
        Sanctum::actingAs($admin);

        $this->putJson("/api/admin/users/{$admin->id}/role", ['role' => 'user'])
            ->assertUnprocessable();

        $this->assertSame('admin', $admin->fresh()->role);
    }

    public function test_admin_can_promote_and_demote_another_user(): void
    {
        Sanctum::actingAs($this->admin());
        $other = User::factory()->create(['email' => 'other@x.com']);

        $this->putJson("/api/admin/users/{$other->id}/role", ['role' => 'admin'])
            ->assertOk()->assertJsonPath('user.role', 'admin');
        $this->assertSame('admin', $other->fresh()->role);

        $this->putJson("/api/admin/users/{$other->id}/role", ['role' => 'user'])
            ->assertOk()->assertJsonPath('user.role', 'user');
        $this->assertSame('user', $other->fresh()->role);
    }

    public function test_non_admin_cannot_change_roles(): void
    {
        $learner = User::factory()->create();
        $other = User::factory()->create();
        Sanctum::actingAs($learner);

        $this->putJson("/api/admin/users/{$other->id}/role", ['role' => 'admin'])->assertForbidden();
        $this->assertNotSame('admin', $other->fresh()->role);
    }

    public function test_learners_see_all_lessons(): void
    {
        $learner = User::create([
            'name' => 'Learner',
            'email' => 'l2@x.com',
            'password' => bcrypt('password123'),
            'email_verified_at' => now(),
        ]);
        $this->lesson(1);
        $this->lesson(2);
        Sanctum::actingAs($learner);

        $this->getJson('/api/lessons')
            ->assertOk()
            ->assertJsonCount(2, 'lessons');
    }

    public function test_admin_can_create_update_and_delete_users(): void
    {
        $admin = $this->admin();
        Sanctum::actingAs($admin);

        $created = $this->postJson('/api/admin/users', [
            'name' => 'New Learner',
            'email' => 'new@x.com',
            'password' => 'password123',
            'role' => 'user',
        ])->assertCreated()->json('user');

        $this->assertDatabaseHas('admin_audit_logs', ['action' => 'user.created']);

        $this->putJson("/api/admin/users/{$created['id']}", ['name' => 'Renamed', 'role' => 'admin'])
            ->assertOk()
            ->assertJsonPath('user.name', 'Renamed')
            ->assertJsonPath('user.role', 'admin');

        $this->deleteJson("/api/admin/users/{$created['id']}")->assertOk();
        $this->assertDatabaseMissing('users', ['id' => $created['id']]);
    }

    public function test_admin_cannot_delete_or_demote_themselves_via_crud(): void
    {
        $admin = $this->admin();
        Sanctum::actingAs($admin);

        $this->deleteJson("/api/admin/users/{$admin->id}")->assertUnprocessable();
        $this->putJson("/api/admin/users/{$admin->id}", ['role' => 'user'])->assertUnprocessable();
        $this->assertSame('admin', $admin->fresh()->role);
    }

    public function test_admin_can_delete_quiz_submission(): void
    {
        $admin = $this->admin();
        $lesson = $this->lesson(1);
        $quiz = Quiz::create(['lesson_id' => $lesson->id, 'passing_score' => 50]);
        $submission = QuizSubmission::create([
            'user_id' => $admin->id,
            'quiz_id' => $quiz->id,
            'answers' => [],
            'score' => 0,
            'passed' => false,
        ]);
        Sanctum::actingAs($admin);

        $this->deleteJson("/api/admin/quizzes/{$quiz->id}/submissions/{$submission->id}")->assertOk();
        $this->assertDatabaseMissing('quiz_submissions', ['id' => $submission->id]);
    }
}
