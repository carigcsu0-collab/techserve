<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('lessons', function (Blueprint $table) {
            $table->foreignId('qualification_id')
                ->nullable()
                ->after('is_published')
                ->constrained('qualifications')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('lessons', function (Blueprint $table) {
            $table->dropConstrainedForeignId('qualification_id');
        });
    }
};
