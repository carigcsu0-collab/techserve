<?php

namespace App\Jobs;

use App\Models\Lesson;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Converts an uploaded lesson video to H.264/AAC MP4 so it plays on every device.
 * The original file is kept if the conversion fails.
 */
class TranscodeLessonVideo implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $timeout = 14400; // 4 hours, for very large files
    public int $tries = 1;

    public function __construct(public int $lessonId)
    {
    }

    public function handle(): void
    {
        $lesson = Lesson::find($this->lessonId);

        if ($lesson === null || $lesson->media_type !== 'video') {
            return;
        }

        $sourceUrl = $lesson->media_url;
        $sourcePath = $this->publicPath($sourceUrl);

        if ($sourcePath === null || ! Storage::disk('public')->exists($sourcePath)) {
            return;
        }

        $disk = Storage::disk('public');
        $outputPath = 'lessons/' . Str::uuid() . '.mp4';
        // storage/app/tmp is on the same HDD mount, so the final move is a rename.
        $tmpFile = storage_path('app/tmp/' . Str::uuid() . '.mp4');

        try {
            $result = Process::timeout($this->timeout)->run([
                'ffmpeg', '-nostdin', '-y', '-loglevel', 'error',
                '-i', $disk->path($sourcePath),
                '-map', '0:v:0', '-map', '0:a:0?',
                '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2',
                '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23', '-pix_fmt', 'yuv420p',
                '-c:a', 'aac', '-b:a', '128k',
                '-movflags', '+faststart',
                $tmpFile,
            ]);

            if (! $result->successful() || ! is_file($tmpFile)) {
                Log::error('Lesson video conversion failed', [
                    'lesson_id' => $lesson->id,
                    'output' => Str::limit($result->errorOutput(), 2000),
                ]);

                return;
            }

            // The lesson may have been edited while converting. Discard the result then.
            $lesson->refresh();
            if ($lesson->media_url !== $sourceUrl) {
                @unlink($tmpFile);

                return;
            }

            $destination = $disk->path($outputPath);
            if (! is_dir(dirname($destination))) {
                mkdir(dirname($destination), 0775, true);
            }
            if (! @rename($tmpFile, $destination)) {
                copy($tmpFile, $destination);
            }

            $lesson->update(['media_url' => asset("storage/{$outputPath}")]);
            $disk->delete($sourcePath);
        } finally {
            if (is_file($tmpFile)) {
                @unlink($tmpFile);
            }
        }
    }

    private function publicPath(?string $url): ?string
    {
        $path = parse_url((string) $url, PHP_URL_PATH) ?? '';

        return str_starts_with($path, '/storage/lessons/')
            ? substr($path, strlen('/storage/'))
            : null;
    }
}
