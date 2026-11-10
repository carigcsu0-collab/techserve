<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\EmailOtpService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function __construct(private EmailOtpService $otp) {}

    /**
     * Step 1: creates the account without a password and emails a code. The
     * password is only accepted after the code is confirmed (see setPassword).
     * Re-registering an email that never finished setup restarts the flow.
     */
    public function register(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255'],
        ]);

        $user = User::where('email', $validated['email'])->first() ?? new User();

        if ($user->exists && $user->email_verified_at && $user->getRawOriginal('password') !== null) {
            throw ValidationException::withMessages([
                'email' => ['The email has already been taken.'],
            ]);
        }

        $user->fill($validated);
        $user->email_verified_at = null;
        $user->password_setup_hash = null;
        $user->password_setup_expires_at = null;
        $user->save();
        $this->sendCode($user);

        return response()->json([
            'verification_required' => true,
            'email' => $user->email,
        ], 201);
    }

    public function login(Request $request)
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (! $user || ! Hash::check($validated['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        if (! $user->email_verified_at) {
            $this->sendCode($user);

            return response()->json([
                'message' => 'Verify your email to continue. We sent you a code.',
                'code' => 'email_unverified',
                'email' => $user->email,
            ], 403);
        }

        $token = $user->createToken('flutter')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $user,
        ]);
    }

    public function verifyEmail(Request $request)
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'code' => ['required', 'digits:6'],
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (! $user || $user->email_verified_at || ! $this->otp->verify($user, $validated['code'])) {
            throw ValidationException::withMessages([
                'code' => ['The code is invalid or has expired.'],
            ]);
        }

        // Existing accounts that already have a password can sign in right away.
        if ($user->getRawOriginal('password') !== null) {
            return response()->json([
                'token' => $user->createToken('flutter')->plainTextToken,
                'user' => $user,
            ]);
        }

        $setupToken = Str::random(64);
        $user->forceFill([
            'password_setup_hash' => hash('sha256', $setupToken),
            'password_setup_expires_at' => now()->addMinutes(15),
        ])->save();

        return response()->json([
            'password_required' => true,
            'setup_token' => $setupToken,
        ]);
    }

    /**
     * Step 3: the verified email owner chooses a password, activating the account.
     */
    public function setPassword(Request $request)
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'setup_token' => ['required', 'string'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (! $user
            || ! $user->email_verified_at
            || $user->getRawOriginal('password') !== null
            || ! $user->password_setup_hash
            || ! $user->password_setup_expires_at
            || $user->password_setup_expires_at->isPast()
            || ! hash_equals($user->password_setup_hash, hash('sha256', $validated['setup_token']))) {
            throw ValidationException::withMessages([
                'password' => ['This setup link has expired. Please register again.'],
            ]);
        }

        $user->forceFill([
            'password' => $validated['password'],
            'password_setup_hash' => null,
            'password_setup_expires_at' => null,
        ])->save();

        return response()->json([
            'token' => $user->createToken('flutter')->plainTextToken,
            'user' => $user,
        ]);
    }

    public function resendVerification(Request $request)
    {
        $validated = $request->validate(['email' => ['required', 'email']]);

        $user = User::where('email', $validated['email'])->first();

        if ($user && ! $user->email_verified_at && ! $this->sendCode($user)) {
            return response()->json([
                'message' => 'Please wait a minute before requesting another code.',
            ], 429);
        }

        return response()->json(['message' => 'A new code has been sent if the account needs verification.']);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out']);
    }

    private function sendCode(User $user): bool
    {
        try {
            return $this->otp->send($user);
        } catch (\Throwable) {
            abort(503, 'We could not send the verification email. Please try again later.');
        }
    }
}
