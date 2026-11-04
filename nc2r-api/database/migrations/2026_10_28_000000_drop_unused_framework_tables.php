<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

// The app only needs reviewers (lessons) and activities (quizzes), so drop the
// unused framework tables for databases created before they were removed.
return new class extends Migration
{
    private array $unused = [
        'jobs', 'job_batches', 'failed_jobs',
        'cache', 'cache_locks',
        'sessions', 'password_reset_tokens',
    ];

    public function up(): void
    {
        foreach ($this->unused as $table) {
            Schema::dropIfExists($table);
        }
    }

    public function down(): void
    {
        // Intentionally empty: these tables are not used.
    }
};
