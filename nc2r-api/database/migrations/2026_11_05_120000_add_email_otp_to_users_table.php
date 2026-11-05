<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('email_otp_hash')->nullable();
            $table->timestamp('email_otp_expires_at')->nullable();
            $table->timestamp('email_otp_sent_at')->nullable();
            $table->unsignedTinyInteger('email_otp_attempts')->default(0);
        });

        // Accounts that already exist were created before email verification existed.
        DB::table('users')->whereNull('email_verified_at')->update(['email_verified_at' => now()]);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['email_otp_hash', 'email_otp_expires_at', 'email_otp_sent_at', 'email_otp_attempts']);
        });
    }
};
