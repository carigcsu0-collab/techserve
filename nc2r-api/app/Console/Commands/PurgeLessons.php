<?php

namespace App\Console\Commands;

use App\Models\Lesson;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

class PurgeLessons extends Command
{
    protected $signature = 'lessons:purge {--force : Required. Confirms that every lesson should be deleted}';

    protected $description = 'Delete all lessons, their quizzes, progress, and uploaded media files';

    public function handle(): int
    {
        if (! $this->option('force')) {
            $this->error('This permanently deletes every lesson. Re-run with --force to confirm.');

            return self::FAILURE;
        }

        $count = 0;

        Lesson::query()->chunkById(100, function ($lessons) use (&$count) {
            foreach ($lessons as $lesson) {
                $path = parse_url((string) $lesson->media_url, PHP_URL_PATH) ?? '';

                if (str_starts_with($path, '/storage/lessons/')) {
                    Storage::disk('public')->delete(substr($path, strlen('/storage/')));
                }

                $lesson->delete();
                $count++;
            }
        });

        $this->info("Deleted {$count} lesson(s).");

        return self::SUCCESS;
    }
}
