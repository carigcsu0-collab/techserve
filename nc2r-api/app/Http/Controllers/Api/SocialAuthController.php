<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Social login. The Flutter app signs the user in with Google/Facebook and
 * sends us the provider token; we verify it with the provider (never trusting
 * the client) and return a normal Sanctum token.
 */
class SocialAuthController extends Controller
{
    public function google(Request $request): JsonResponse
    {
        $validated = $request->validate(['id_token' => ['required', 'string']]);

        $clientIds = array_filter(array_map('trim', explode(',', (string) config('services.google.client_ids'))));
        if (! $clientIds) {
            abort(503, 'Google login is not configured on the server.');
        }

        $response = $this->get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $validated['id_token']]);
        $claims = $response->json();

        if (! $response->ok()
            || ! in_array($claims['aud'] ?? null, $clientIds, true)
            || ! filter_var($claims['email_verified'] ?? false, FILTER_VALIDATE_BOOLEAN)
            || empty($claims['sub']) || empty($claims['email'])) {
            $this->invalid('google');
        }

        return $this->issueToken('google_id', $claims['sub'], $claims['email'], $claims['name'] ?? null);
    }

    public function facebook(Request $request): JsonResponse
    {
        $validated = $request->validate(['access_token' => ['required', 'string']]);

        $appId = config('services.facebook.app_id');
        $secret = config('services.facebook.app_secret');
        if (! $appId || ! $secret) {
            abort(503, 'Facebook login is not configured on the server.');
        }

        $debug = $this->get('https://graph.facebook.com/debug_token', [
            'input_token' => $validated['access_token'],
            'access_token' => $appId.'|'.$secret,
        ])->json('data');

        if (! ($debug['is_valid'] ?? false) || ($debug['app_id'] ?? null) !== (string) $appId) {
            $this->invalid('facebook');
        }

        $profile = $this->get('https://graph.facebook.com/me', [
            'fields' => 'id,name,email',
            'access_token' => $validated['access_token'],
        ])->json();

        if (empty($profile['id'])) {
            $this->invalid('facebook');
        }
        if (empty($profile['email'])) {
            throw ValidationException::withMessages([
                'access_token' => ['Your Facebook account has no email address. Please use another sign-in method.'],
            ]);
        }

        return $this->issueToken('facebook_id', $profile['id'], $profile['email'], $profile['name'] ?? null);
    }

    private function issueToken(string $column, string $providerId, string $email, ?string $name): JsonResponse
    {
        $user = User::where($column, $providerId)->first();

        if (! $user && $user = User::where('email', $email)->first()) {
            // Facebook emails are not always verified, so never let them take over an admin account.
            if ($column === 'facebook_id' && $user->role === 'admin') {
                throw ValidationException::withMessages([
                    'access_token' => ['This account cannot be linked to Facebook. Sign in with your password or Google.'],
                ]);
            }
        }

        if ($user) {
            if ($user->$column !== $providerId) {
                $user->forceFill([$column => $providerId])->save();
            }
        } else {
            $user = new User([
                'name' => $name ?: Str::before($email, '@'),
                'email' => $email,
                // Social accounts never use a password; keep a random one so the column stays non-null.
                'password' => Str::random(40),
            ]);
            $user->forceFill([$column => $providerId, 'email_verified_at' => now()])->save();
        }

        return response()->json([
            'token' => $user->createToken('flutter')->plainTextToken,
            'user' => $user,
        ]);
    }

    private function get(string $url, array $query)
    {
        try {
            return Http::timeout(10)->acceptJson()->get($url, $query);
        } catch (ConnectionException) {
            abort(503, 'Could not reach the sign-in provider. Try again.');
        }
    }

    private function invalid(string $field): never
    {
        throw ValidationException::withMessages([
            $field === 'google' ? 'id_token' : 'access_token' => ['The sign-in token is invalid or expired.'],
        ]);
    }
}
