<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAuditLog;
use App\Models\Lesson;
use App\Models\QuizSubmission;
use App\Models\User;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function index()
    {
        $submissions = QuizSubmission::query();
        $totalSubmissions = (clone $submissions)->count();
        $passed = (clone $submissions)->where('passed', true)->count();

        return response()->json([
            'stats' => [
                'users' => User::count(),
                'admins' => User::where('role', 'admin')->count(),
                'lessons' => Lesson::count(),
                'quiz_submissions' => $totalSubmissions,
                'pass_rate' => $totalSubmissions > 0 ? (int) round($passed * 100 / $totalSubmissions) : 0,
                'average_score' => $totalSubmissions > 0 ? round((float) (clone $submissions)->avg('score'), 1) : 0,
            ],
            'recent_activity' => AdminAuditLog::with('admin:id,name')
                ->latest('id')
                ->limit(5)
                ->get()
                ->map(fn (AdminAuditLog $log) => $log->toApi())
                ->values(),
        ]);
    }
}
