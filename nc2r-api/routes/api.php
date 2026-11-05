<?php

use App\Http\Controllers\Api\Admin\LessonController as AdminLessonController;
use App\Http\Controllers\Api\Admin\QuestionController as AdminQuestionController;
use App\Http\Controllers\Api\Admin\QuizController as AdminQuizController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\LessonController;
use App\Http\Controllers\Api\QuizController;
use App\Http\Controllers\Api\SocialAuthController;
use App\Http\Controllers\Api\UserController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/verify-email', [AuthController::class, 'verifyEmail'])->middleware('throttle:10,1');
Route::post('/resend-verification', [AuthController::class, 'resendVerification'])->middleware('throttle:5,1');
Route::post('/auth/google', [SocialAuthController::class, 'google'])->middleware('throttle:20,1');
Route::post('/auth/facebook', [SocialAuthController::class, 'facebook'])->middleware('throttle:20,1');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::put('/user/profile', [UserController::class, 'updateProfile']);
    Route::put('/user/password', [UserController::class, 'updatePassword']);

    Route::get('/lessons', [LessonController::class, 'index']);
    Route::get('/lessons/{lesson}/quiz', [QuizController::class, 'show']);
    Route::post('/quizzes/{quiz}/submit', [QuizController::class, 'submit']);
});

Route::middleware(['auth:sanctum', 'admin'])->prefix('admin')->group(function () {
    Route::post('/lessons', [AdminLessonController::class, 'store']);
    Route::put('/lessons/{lesson}', [AdminLessonController::class, 'update']);
    Route::delete('/lessons/{lesson}', [AdminLessonController::class, 'destroy']);

    Route::post('/lessons/{lesson}/quiz', [AdminQuizController::class, 'store']);
    Route::put('/quizzes/{quiz}', [AdminQuizController::class, 'update']);
    Route::delete('/quizzes/{quiz}', [AdminQuizController::class, 'destroy']);
    Route::get('/quizzes/{quiz}/submissions', [AdminQuizController::class, 'submissions']);

    Route::post('/quizzes/{quiz}/questions', [AdminQuestionController::class, 'store']);
    Route::put('/questions/{question}', [AdminQuestionController::class, 'update']);
    Route::delete('/questions/{question}', [AdminQuestionController::class, 'destroy']);
});
