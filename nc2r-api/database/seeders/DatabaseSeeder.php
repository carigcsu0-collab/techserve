<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        User::updateOrCreate(
            ['email' => 'test@example.com'],
            ['name' => 'Test User', 'role' => 'user', 'password' => 'password'],
        );

        User::updateOrCreate(
            ['email' => 'admin@nc2r.test'],
            [
                'name' => 'Admin',
                'role' => 'admin',
                'password' => 'password',
            ],
        );

        $this->call(LessonSeeder::class);
    }
}
