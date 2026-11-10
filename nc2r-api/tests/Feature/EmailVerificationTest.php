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

    private function register(string $name = 'Ann', string $email = 'ann@x.com')
    {
        return $this->postJson('/api/register', ['name' => $name, 'email' => $email]);
    }

    public function test_register_needs_no_password_and_sends_code(): void
    {
        Mail::fake();

        $this->register()->assertCreated()
            ->assertJsonPath('verification_required', true)
            ->assertJsonMissingPath('token');

        $user = User::where('email', 'ann@x.com')->first();
        $this->assertNull($user->email_verified_at);
        $this->assertNull($user->getRawOriginal('password'));
        $this->codeSentTo('ann@x.com');
    }

    public function test_correct_code_returns_setup_token_not_session(): void
    {
        Mail::fake();
        $this->register()->assertCreated();

        $this->postJson('/api/verify-email', ['email' => 'ann@x.com', 'code' => $this->codeSentTo('ann@x.com')])
            ->assertOk()
            ->assertJsonPath('password_required', true)
            ->assertJsonStructure(['setup_token'])
            ->assertJsonMissingPath('token');

        $this->assertNotNull(User::where('email', 'ann@x.com')->first()->email_verified_at);
    }

    public function test_full_flow_activates_account_with_password(): void
    {
        Mail::fake();
        $this->register()->assertCreated();

        $setup = $this->postJson('/api/verify-email', [
            'email' => 'ann@x.com', 'code' => $this->codeSentTo('ann@x.com'),
        ])->json('setup_token');

        $this->postJson('/api/set-password', [
            'email' => 'ann@x.com', 'setup_token' => $setup,
            'password' => 'password123', 'password_confirmation' => 'password123',
        ])->assertOk()->assertJsonStructure(['token', 'user']);

        $this->postJson('/api/login', ['email' => 'ann@x.com', 'password' => 'password123'])->assertOk();

        // The setup token is single use.
        $this->postJson('/api/set-password', [
            'email' => 'ann@x.com', 'setup_token' => $setup,
            'password' => 'another12345', 'password_confirmation' => 'another12345',
        ])->assertStatus(422);
    }

    public function test_password_cannot_be_set_without_valid_setup_token(): void
    {
        Mail::fake();
        $this->register()->assertCreated();

        $this->postJson('/api/set-password', [
            'email' => 'ann@x.com', 'setup_token' => 'nope',
            'password' => 'password123', 'password_confirmation' => 'password123',
        ])->assertStatus(422);
    }

    public function test_account_without_password_cannot_log_in(): void
    {
        Mail::fake();
        $this->register()->assertCreated();

        $this->postJson('/api/login', ['email' => 'ann@x.com', 'password' => 'password123'])
            ->assertStatus(422);
    }

    public function test_wrong_code_is_rejected_and_locks_after_max_attempts(): void
    {
        Mail::fake();
        $this->register()->assertCreated();

        $real = $this->codeSentTo('ann@x.com');
        $wrong = $real === '000000' ? '111111' : '000000';

        for ($i = 0; $i < EmailOtpService::MAX_ATTEMPTS; $i++) {
            $this->postJson('/api/verify-email', ['email' => 'ann@x.com', 'code' => $wrong])
                ->assertStatus(422)->assertJsonValidationErrors('code');
        }

        $this->postJson('/api/verify-email', ['email' => 'ann@x.com', 'code' => $real])
            ->assertStatus(422);
        $this->assertNull(User::where('email', 'ann@x.com')->first()->email_verified_at);
    }

    public function test_expired_code_is_rejected(): void
    {
        Mail::fake();
        $this->register()->assertCreated();

        $code = $this->codeSentTo('ann@x.com');
        DB::table('users')->where('email', 'ann@x.com')->update(['email_otp_expires_at' => now()->subMinute()]);

        $this->postJson('/api/verify-email', ['email' => 'ann@x.com', 'code' => $code])
            ->assertStatus(422);
    }

    public function test_resend_is_rate_limited_by_cooldown(): void
    {
        Mail::fake();
        $this->register()->assertCreated();

        $this->postJson('/api/resend-verification', ['email' => 'ann@x.com'])
            ->assertStatus(429);

        Mail::assertSentCount(1);
    }

    public function test_email_that_never_finished_setup_can_be_registered_again(): void
    {
        Mail::fake();
        $this->register()->assertCreated();

        User::where('email', 'ann@x.com')->update(['email_otp_sent_at' => now()->subMinutes(5)]);

        $this->register('Ann Two')->assertCreated();

        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseHas('users', ['email' => 'ann@x.com', 'name' => 'Ann Two']);
    }

    public function test_active_email_cannot_be_registered_again(): void
    {
        User::factory()->create(['email' => 'ann@x.com']);

        $this->register()->assertStatus(422)->assertJsonValidationErrors('email');
    }
}
