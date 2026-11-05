<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAuditLog;
use App\Models\Lesson;
use App\Models\QuizSubmission;
use App\Models\User;
use Illuminate\Http\Request;

class UserController extends Controller
{
    public function index(Request $request)
    {
        $search = trim((string) $request->query('q', ''));

        $users = User::query()
            ->when($search !== '', function ($query) use ($search) {
                $query->where(function ($q) use ($search) {
                    $q->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%");
                });
            })
            ->orderBy('name')
            ->paginate(20);

        return response()->json([
            'users' => collect($users->items())->map(fn (User $user) => $this->summary($user))->values(),
            'next_page' => $users->hasMorePages() ? $users->currentPage() + 1 : null,
        ]);
    }

    public function show(User $user)
    {
        $completedLessons = $user->completedLessons()
            ->orderBy('order_index')
            ->get(['lessons.id', 'lessons.title', 'lessons.order_index'])
            ->map(fn (Lesson $lesson) => [
                'id' => $lesson->id,
                'title' => $lesson->title,
                'order_index' => $lesson->order_index,
            ])
            ->values();

        $submissions = QuizSubmission::with('quiz.lesson:id,title')
            ->where('user_id', $user->id)
            ->latest('id')
            ->limit(50)
            ->get()
            ->map(fn (QuizSubmission $submission) => [
                'id' => $submission->id,
                'lesson_title' => $submission->quiz?->lesson?->title,
                'score' => $submission->score,
                'passed' => $submission->passed,
                'created_at' => $submission->created_at?->toISOString(),
            ])
            ->values();

        return response()->json([
            'user' => $this->summary($user),
            'progress' => [
                'total_lessons' => Lesson::published()->count(),
                'completed_count' => $completedLessons->count(),
                'completed_lessons' => $completedLessons,
            ],
            'quiz_submissions' => $submissions,
        ]);
    }

    public function updateRole(Request $request, User $user)
    {
        $validated = $request->validate([
            'role' => ['required', 'in:admin,user'],
        ]);

        $admin = $request->user();

        if ($user->id === $admin->id && $validated['role'] !== 'admin') {
            return response()->json(['message' => 'You cannot remove your own admin role.'], 422);
        }

        if ($user->role !== $validated['role']) {
            $user->update(['role' => $validated['role']]);

            AdminAuditLog::record(
                $admin,
                'user.role_changed',
                "Set {$user->email} role to {$validated['role']}",
                $user,
            );
        }

        return response()->json(['user' => $this->summary($user->fresh())]);
    }

    private function summary(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'email_verified' => $user->email_verified_at !== null,
            'created_at' => $user->created_at?->toISOString(),
        ];
    }
}
