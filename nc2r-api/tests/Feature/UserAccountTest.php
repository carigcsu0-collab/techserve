<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

class UserAccountTest extends TestCase
{
    use RefreshDatabase;

    private function verifiedUser(string $password = 'password123'): User
    {
        return User::create([
            'name' => 'Ann',
            'email' => 'ann@x.com',
            'password' => Hash::make($password),
            'email_verified_at' => now(),
        ]);
    }

    public function test_profile_name_can_be_updated(): void
    {
        $user = $this->verifiedUser();
        $token = $user->createToken('flutter')->plainTextToken;

        $this->putJson('/api/user/profile', ['name' => 'Ann Cruz'], [
            'Authorization' => "Bearer $token",
        ])->assertOk()->assertJsonPath('user.name', 'Ann Cruz');

        $this->assertSame('Ann Cruz', $user->fresh()->name);
    }

    public function test_token_is_valid_for_five_days_then_expires(): void
    {
        $user = $this->verifiedUser();
        $token = $user->createToken('flutter')->plainTextToken;

        Carbon::setTestNow(now()->addDays(4));
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/user', ['Authorization' => 'Bearer '.$token])->assertOk();

        Carbon::setTestNow(now()->addDays(2));
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/user', ['Authorization' => 'Bearer '.$token])->assertUnauthorized();

        Carbon::setTestNow();
    }

    public function test_profile_name_is_required(): void
    {
        $user = $this->verifiedUser();
        $token = $user->createToken('flutter')->plainTextToken;

        $this->putJson('/api/user/profile', ['name' => ''], [
            'Authorization' => "Bearer $token",
        ])->assertUnprocessable()->assertJsonValidationErrors('name');
    }

    public function test_password_change_requires_the_current_password(): void
    {
        $user = $this->verifiedUser();
        $token = $user->createToken('flutter')->plainTextToken;

        $this->putJson('/api/user/password', [
            'current_password' => 'wrong-password',
            'password' => 'newpassword1',
            'password_confirmation' => 'newpassword1',
        ], ['Authorization' => "Bearer $token"])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('current_password');

        $this->assertTrue(Hash::check('password123', $user->fresh()->password));
    }

    public function test_password_change_revokes_other_sessions_only(): void
    {
        $user = $this->verifiedUser();
        $current = $user->createToken('phone')->plainTextToken;
        $other = $user->createToken('tablet')->plainTextToken;

        $this->putJson('/api/user/password', [
            'current_password' => 'password123',
            'password' => 'newpassword1',
            'password_confirmation' => 'newpassword1',
        ], ['Authorization' => "Bearer $current"])->assertOk();

        $this->assertTrue(Hash::check('newpassword1', $user->fresh()->password));
        $this->assertSame(1, PersonalAccessToken::where('tokenable_id', $user->id)->count());

        // The test app caches the resolved guard user between requests; reset it so
        // each request re-checks its own token.
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/user', ['Authorization' => "Bearer $other"])->assertUnauthorized();

        $this->app['auth']->forgetGuards();
        $this->getJson('/api/user', ['Authorization' => "Bearer $current"])->assertOk();
    }

    public function test_password_must_be_at_least_eight_characters(): void
    {
        $user = $this->verifiedUser();
        $token = $user->createToken('flutter')->plainTextToken;

        $this->putJson('/api/user/password', [
            'current_password' => 'password123',
            'password' => 'short',
            'password_confirmation' => 'short',
        ], ['Authorization' => "Bearer $token"])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('password');
    }
}
