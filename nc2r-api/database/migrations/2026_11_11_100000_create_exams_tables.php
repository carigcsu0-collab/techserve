<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('exams', function (Blueprint $table) {
            $table->id();
            $table->foreignId('qualification_id')->constrained()->cascadeOnDelete();
            $table->enum('type', ['pre', 'post']);
            $table->unsignedInteger('passing_score')->default(75);
            // How many questions each learner gets (random pick from the bank); null = all.
            $table->unsignedInteger('question_count')->nullable();
            $table->timestamps();
            $table->unique(['qualification_id', 'type']);
        });

        Schema::create('exam_questions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('exam_id')->constrained()->cascadeOnDelete();
            $table->text('question_text');
            $table->json('options');
            $table->string('correct_answer');
            $table->timestamps();
        });

        Schema::create('exam_attempts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('exam_id')->constrained()->cascadeOnDelete();
            $table->unsignedInteger('score');
            $table->boolean('passed');
            $table->unsignedInteger('correct');
            $table->unsignedInteger('total');
            $table->json('answers')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('exam_attempts');
        Schema::dropIfExists('exam_questions');
        Schema::dropIfExists('exams');
    }
};
