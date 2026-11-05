<?php

namespace Tests\Feature;

use App\Mail\EmailOtpMail;
use App\Models\User;
use App\Services\EmailOtpService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class EmailVerificationTest extends TestCase
{
    use RefreshDatabase;

    /** Reads the code that was emailed, since only its hash is stored. */
    private function codeSentTo(string $email): string
    {
        $code = null;
        Mail::assertSent(EmailOtpMail::class, function (EmailOtpMail $mail) use (&$code, $email) {
            $code = $mail->code;

            return $mail->hasTo($email);
        });

        return $code;
    }

    public function test_register_sends_code_and_issues_no_token(): void
    {
        Mail::fake();

        $this->postJson('/api/register', [
            'name' => 'Ann', 'email' => 'ann@x.com',
            'password' => 'password123', 'password_confirmation' => 'password123',
        ])->assertCreated()
            ->assertJsonPath('verification_required', true)
            ->assertJsonMissingPath('token');

        $this->assertNull(User::where('email', 'ann@x.com')->first()->email_verified_at);
        $this->codeSentTo('ann@x.com');
    }

    public function test_unverified_user_cannot_log_in_until_verified(): void
    {
        Mail::fake();
        $this->postJson('/api/register', [
            'name' => 'Ann', 'email' => 'ann@x.com',
            'password' => 'password123', 'password_confirmation' => 'password123',
        ])->assertCreated();

        $this->postJson('/api/login', ['email' => 'ann@x.com', 'password' => 'password123'])
            ->assertStatus(403)->assertJsonPath('code', 'email_unverified');
    }

    public function test_correct_code_verifies_and_returns_token(): void
    {
        Mail::fake();
        $this->postJson('/api/register', [
            'name' => 'Ann', 'email' => 'ann@x.com',
            'password' => 'password123', 'password_confirmation' => 'password123',
        ])->assertCreated();

        $this->postJson('/api/verify-email', ['email' => 'ann@x.com', 'code' => $this->codeSentTo('ann@x.com')])
            ->assertOk()->assertJsonStructure(['token', 'user']);

        $this->assertNotNull(User::where('email', 'ann@x.com')->first()->email_verified_at);
        $this->postJson('/api/login', ['email' => 'ann@x.com', 'password' => 'password123'])->assertOk();
    }

    public function test_wrong_code_is_rejected_and_locks_after_max_attempts(): void
    {
        Mail::fake();
        $this->postJson('/api/register', [
            'name' => 'Ann', 'email' => 'ann@x.com',
            'password' => 'password123', 'password_confirmation' => 'password123',
        ])->assertCreated();

        $real = $this->codeSentTo('ann@x.com');
        $wrong = $real === '000000' ? '111111' : '000000';

        for ($i = 0; $i < EmailOtpService::MAX_ATTEMPTS; $i++) {
            $this->postJson('/api/verify-email', ['email' => 'ann@x.com', 'code' => $wrong])
                ->assertStatus(422)->assertJsonValidationErrors('code');
        }

        // Even the right code no longer works once attempts are used up.
        $this->postJson('/api/verify-email', ['email' => 'ann@x.com', 'code' => $real])
            ->assertStatus(422);
        $this->assertNull(User::where('email', 'ann@x.com')->first()->email_verified_at);
    }

    public function test_expired_code_is_rejected(): void
    {
        Mail::fake();
        $this->postJson('/api/register', [
            'name' => 'Ann', 'email' => 'ann@x.com',
            'password' => 'password123', 'password_confirmation' => 'password123',
        ])->assertCreated();

        $code = $this->codeSentTo('ann@x.com');
        DB::table('users')->where('email', 'ann@x.com')->update(['email_otp_expires_at' => now()->subMinute()]);

        $this->postJson('/api/verify-email', ['email' => 'ann@x.com', 'code' => $code])
            ->assertStatus(422);
    }

    public function test_resend_is_rate_limited_by_cooldown(): void
    {
        Mail::fake();
        $this->postJson('/api/register', [
            'name' => 'Ann', 'email' => 'ann@x.com',
            'password' => 'password123', 'password_confirmation' => 'password123',
        ])->assertCreated();

        $this->postJson('/api/resend-verification', ['email' => 'ann@x.com'])
            ->assertStatus(429);

        Mail::assertSentCount(1);
    }

    public function test_unverified_email_can_be_registered_again(): void
    {
        Mail::fake();
        $this->postJson('/api/register', [
            'name' => 'Ann', 'email' => 'ann@x.com',
            'password' => 'password123', 'password_confirmation' => 'password123',
        ])->assertCreated();

        User::where('email', 'ann@x.com')->update(['email_otp_sent_at' => now()->subMinutes(5)]);

        $this->postJson('/api/register', [
            'name' => 'Ann Two', 'email' => 'ann@x.com',
            'password' => 'newpassword1', 'password_confirmation' => 'newpassword1',
        ])->assertCreated();

        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseHas('users', ['email' => 'ann@x.com', 'name' => 'Ann Two']);
    }

    public function test_verified_email_cannot_be_registered_again(): void
    {
        User::factory()->create(['email' => 'ann@x.com']);

        $this->postJson('/api/register', [
            'name' => 'Ann', 'email' => 'ann@x.com',
            'password' => 'password123', 'password_confirmation' => 'password123',
        ])->assertStatus(422)->assertJsonValidationErrors('email');
    }
}
