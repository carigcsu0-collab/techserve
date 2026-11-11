<?php

namespace App\Services;

use App\Mail\EmailOtpMail;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * One-time codes emailed to prove the user owns the address.
 * Only an HMAC of the code is stored, so a leaked database row can't be used to verify.
 */
class EmailOtpService
{
    public const TTL_MINUTES = 10;

    public const RESEND_COOLDOWN_SECONDS = 60;

    public const MAX_ATTEMPTS = 5;

    /**
     * Generates and emails a new code. Returns false while the resend cooldown is active.
     */
    public function send(User $user): bool
    {
        if ($user->email_otp_sent_at && $user->email_otp_sent_at->diffInSeconds(now()) < self::RESEND_COOLDOWN_SECONDS) {
            return false;
        }

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $user->forceFill([
            'email_otp_hash' => $this->hash($code),
            'email_otp_expires_at' => now()->addMinutes(self::TTL_MINUTES),
            'email_otp_sent_at' => now(),
            'email_otp_attempts' => 0,
        ])->save();

        try {
            Mail::to($user->email)->send(new EmailOtpMail($code, self::TTL_MINUTES));
        } catch (Throwable $e) {
            // Don't make the user wait out the cooldown for a code that was never delivered.
            $user->forceFill(['email_otp_sent_at' => null])->save();
            Log::error('Failed to send verification email', ['user_id' => $user->id, 'error' => $e->getMessage()]);
            throw $e;
        }

        return true;
    }

    /**
     * Checks a code. Consumes an attempt on every wrong guess and clears the code once used.
     */
    public function verify(User $user, string $code): bool
    {
        if (! $user->email_otp_hash
            || ! $user->email_otp_expires_at
            || Carbon::now()->greaterThan($user->email_otp_expires_at)
            || $user->email_otp_attempts >= self::MAX_ATTEMPTS) {
            return false;
        }

        if (! hash_equals($user->email_otp_hash, $this->hash($code))) {
            $user->increment('email_otp_attempts');

            return false;
        }

        $user->forceFill([
            'email_otp_hash' => null,
            'email_otp_expires_at' => null,
            'email_otp_attempts' => 0,
            'email_verified_at' => now(),
        ])->save();

        return true;
    }

    private function hash(string $code): string
    {
        return hash_hmac('sha256', $code, (string) config('app.key'));
    }
}
