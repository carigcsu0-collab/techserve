<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SocialLoginTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'services.google.client_ids' => 'web-id,android-id',
            'services.facebook.app_id' => '123',
            'services.facebook.app_secret' => 'secret',
        ]);
    }

    private function fakeGoogle(array $claims, int $status = 200): void
    {
        Http::fake(['oauth2.googleapis.com/*' => Http::response($claims, $status)]);
    }

    public function test_google_login_creates_user_and_returns_token(): void
    {
        $this->fakeGoogle(['aud' => 'web-id', 'sub' => 'g1', 'email' => 'a@x.com', 'email_verified' => 'true', 'name' => 'Ann']);

        $this->postJson('/api/auth/google', ['id_token' => 'tok'])
            ->assertOk()->assertJsonPath('user.email', 'a@x.com')->assertJsonStructure(['token']);

        $this->assertDatabaseHas('users', ['email' => 'a@x.com', 'google_id' => 'g1', 'role' => 'user']);
    }

    public function test_google_login_links_existing_email_account(): void
    {
        $existing = User::factory()->create(['email' => 'a@x.com']);
        $this->fakeGoogle(['aud' => 'android-id', 'sub' => 'g1', 'email' => 'a@x.com', 'email_verified' => 'true']);

        $this->postJson('/api/auth/google', ['id_token' => 'tok'])->assertOk()->assertJsonPath('user.id', $existing->id);
        $this->assertSame('g1', $existing->fresh()->google_id);
        $this->assertSame(1, User::count());
    }

    public function test_google_rejects_wrong_audience_and_bad_token(): void
    {
        $this->fakeGoogle(['aud' => 'other-app', 'sub' => 'g1', 'email' => 'a@x.com', 'email_verified' => 'true']);
        $this->postJson('/api/auth/google', ['id_token' => 'tok'])->assertStatus(422);

        $this->fakeGoogle(['error' => 'invalid_token'], 400);
        $this->postJson('/api/auth/google', ['id_token' => 'tok'])->assertStatus(422);
        $this->assertSame(0, User::count());
    }

    public function test_facebook_login_works(): void
    {
        Http::fake([
            'graph.facebook.com/debug_token*' => Http::response(['data' => ['is_valid' => true, 'app_id' => '123']]),
            'graph.facebook.com/me*' => Http::response(['id' => 'f1', 'name' => 'Fay', 'email' => 'f@x.com']),
        ]);

        $this->postJson('/api/auth/facebook', ['access_token' => 'tok'])
            ->assertOk()->assertJsonPath('user.email', 'f@x.com');
        $this->assertDatabaseHas('users', ['facebook_id' => 'f1']);
    }

    public function test_facebook_rejects_token_for_other_app_and_admin_takeover(): void
    {
        Http::fake(['graph.facebook.com/debug_token*' => Http::response(['data' => ['is_valid' => true, 'app_id' => '999']])]);
        $this->postJson('/api/auth/facebook', ['access_token' => 'tok'])->assertStatus(422);

        User::factory()->create(['email' => 'boss@x.com', 'role' => 'admin']);
        Http::fake([
            'graph.facebook.com/debug_token*' => Http::response(['data' => ['is_valid' => true, 'app_id' => '123']]),
            'graph.facebook.com/me*' => Http::response(['id' => 'f2', 'name' => 'Eve', 'email' => 'boss@x.com']),
        ]);
        $this->postJson('/api/auth/facebook', ['access_token' => 'tok'])->assertStatus(422);
    }

    public function test_not_configured_returns_503(): void
    {
        config(['services.google.client_ids' => null]);
        $this->postJson('/api/auth/google', ['id_token' => 'tok'])->assertStatus(503);
    }
}
