<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Lesson;
use App\Services\LessonProgress;
use Illuminate\Http\Request;

class LessonController extends Controller
{
    /**
     * All lessons in display order with gated progression per qualification.
     */
    public function index(Request $request, LessonProgress $progress)
    {
        $user = $request->user();

        $lessons = Lesson::query()
            ->when(! $user->isAdmin(), fn ($query) => $query->published())
            ->orderBy('order_index')
            ->get();

        return response()->json(['lessons' => $progress->present($lessons, $user)->values()]);
    }
}
