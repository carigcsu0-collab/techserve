<?php

namespace Tests\Feature;

use App\Models\AdminAuditLog;
use App\Models\Lesson;
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

    private function lesson(int $order, bool $published = true): Lesson
    {
        return Lesson::create([
            'title' => "Lesson {$order}",
            'description' => 'Body',
            'media_type' => 'image',
            'media_url' => 'https://example.com/' . $order . '.png',
            'order_index' => $order,
            'is_published' => $published,
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
        $this->lesson(2, false);
        AdminAuditLog::record($admin, 'lesson.created', 'Created lesson');
        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/dashboard')
            ->assertOk()
            ->assertJsonPath('stats.lessons', 2)
            ->assertJsonPath('stats.published_lessons', 1)
            ->assertJsonPath('stats.draft_lessons', 1)
            ->assertJsonPath('recent_activity.0.summary', 'Created lesson');
    }

    public function test_publish_toggle_is_audited(): void
    {
        $admin = $this->admin();
        $lesson = $this->lesson(1, false);
        Sanctum::actingAs($admin);

        $this->putJson("/api/admin/lessons/{$lesson->id}/publish", ['is_published' => true])
            ->assertOk()
            ->assertJsonPath('lesson.is_published', true);

        $this->assertDatabaseHas('admin_audit_logs', ['action' => 'lesson.published', 'subject_id' => $lesson->id]);
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

    public function test_learners_do_not_see_draft_lessons(): void
    {
        $learner = User::create([
            'name' => 'Learner',
            'email' => 'l2@x.com',
            'password' => bcrypt('password123'),
            'email_verified_at' => now(),
        ]);
        $this->lesson(1);
        $this->lesson(2, false);
        Sanctum::actingAs($learner);

        $this->getJson('/api/lessons')
            ->assertOk()
            ->assertJsonCount(1, 'lessons');
    }
}
