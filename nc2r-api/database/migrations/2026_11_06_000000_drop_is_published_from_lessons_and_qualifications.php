<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        foreach (['lessons', 'qualifications'] as $table) {
            if (Schema::hasColumn($table, 'is_published')) {
                Schema::table($table, function (Blueprint $blueprint) {
                    $blueprint->dropColumn('is_published');
                });
            }
        }
    }

    public function down(): void
    {
        foreach (['lessons', 'qualifications'] as $table) {
            if (! Schema::hasColumn($table, 'is_published')) {
                Schema::table($table, function (Blueprint $blueprint) {
                    $blueprint->boolean('is_published')->default(true);
                });
            }
        }
    }
};
