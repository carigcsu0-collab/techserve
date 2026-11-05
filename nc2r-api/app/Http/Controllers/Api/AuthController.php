<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\EmailOtpService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function __construct(private EmailOtpService $otp) {}

    /**
     * Creates the account unverified and emails a code. No token is issued until
     * the code is confirmed. Re-registering an unverified email replaces that
     * pending account, since the new code proves the address belongs to the person.
     */
    public function register(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = User::where('email', $validated['email'])->first() ?? new User();

        if ($user->exists && $user->email_verified_at) {
            throw ValidationException::withMessages([
                'email' => ['The email has already been taken.'],
            ]);
        }

        $user->fill($validated)->save();
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

        $token = $user->createToken('flutter')->plainTextToken;

        return response()->json([
            'token' => $token,
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
