<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Large files arrive in small pieces so a flaky connection or proxy only costs one
 * retried piece instead of the whole upload. Pieces are written at their offset into
 * a single .part file, which is moved into public storage once the lesson is saved.
 */
class ChunkedUpload
{
    public const MAX_BYTES = 2147483648; // 2 GB

    public const MAX_IMAGE_BYTES = 52428800; // 50 MB

    public const MAX_CHUNK_BYTES = 16777216; // 16 MB

    public const VIDEO_EXTENSIONS = [
        'mp4', 'm4v', 'mov', 'webm', 'mkv', 'avi', 'wmv', 'flv', 'f4v', 'mpeg', 'mpg',
        'mpe', 'm2v', 'ts', 'm2ts', 'mts', '3gp', '3g2', 'ogv', 'vob', 'asf', 'rm', 'rmvb', 'divx',
    ];

    public const IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

    public function begin(User $user, string $name, int $size): string
    {
        $this->purgeStale();

        $extension = strtolower(pathinfo($name, PATHINFO_EXTENSION));
        if (! in_array($extension, array_merge(self::VIDEO_EXTENSIONS, self::IMAGE_EXTENSIONS), true)) {
            throw ValidationException::withMessages(['name' => ['This file type is not supported.']]);
        }

        $id = bin2hex(random_bytes(16));
        touch($this->partPath($id));
        file_put_contents($this->metaPath($id), json_encode([
            'user' => $user->id,
            'extension' => $extension,
            'size' => $size,
        ]));

        return $id;
    }

    /** Writes one piece at [$offset]. Re-sending a piece simply overwrites it. Returns bytes received. */
    public function append(User $user, string $id, int $offset, UploadedFile $chunk): int
    {
        $meta = $this->meta($user, $id);
        $part = $this->partPath($id);

        clearstatcache(true, $part);
        $current = (int) filesize($part);
        $length = (int) $chunk->getSize();

        if ($offset < 0 || $offset > $current || $offset + $length > $meta['size']) {
            throw ValidationException::withMessages(['offset' => ['Upload piece is out of order.']]);
        }

        $out = fopen($part, 'c+b');
        $in = fopen($chunk->getRealPath(), 'rb');
        fseek($out, $offset);
        stream_copy_to_stream($in, $out);
        fclose($in);
        fclose($out);

        clearstatcache(true, $part);

        return (int) filesize($part);
    }

    /**
     * Validates the finished upload and moves it into public storage.
     * Returns the storage path (relative to the public disk).
     */
    public function finalize(User $user, string $id, string $mediaType): string
    {
        $meta = $this->meta($user, $id);
        $part = $this->partPath($id);

        clearstatcache(true, $part);
        if ((int) filesize($part) !== (int) $meta['size']) {
            throw ValidationException::withMessages(['upload_id' => ['The upload is incomplete. Please try again.']]);
        }

        $allowed = $mediaType === 'image' ? self::IMAGE_EXTENSIONS : self::VIDEO_EXTENSIONS;
        if (! in_array($meta['extension'], $allowed, true)) {
            throw ValidationException::withMessages(['upload_id' => ["The file must be a {$mediaType}."]]);
        }
        if ($mediaType === 'image' && $meta['size'] > self::MAX_IMAGE_BYTES) {
            throw ValidationException::withMessages(['upload_id' => ['Images must be 50 MB or smaller.']]);
        }

        $relative = 'lessons/' . Str::random(40) . '.' . $meta['extension'];
        $target = Storage::disk('public')->path($relative);
        if (! is_dir(dirname($target))) {
            mkdir(dirname($target), 0775, true);
        }

        if (! @rename($part, $target)) {
            copy($part, $target);
            unlink($part);
        }
        @unlink($this->metaPath($id));

        return $relative;
    }

    private function meta(User $user, string $id): array
    {
        abort_unless(preg_match('/^[a-f0-9]{32}$/', $id) === 1 && is_file($this->metaPath($id)), 404);

        $meta = json_decode((string) file_get_contents($this->metaPath($id)), true);
        abort_unless(is_array($meta) && ($meta['user'] ?? null) === $user->id, 404);

        return $meta;
    }

    private function dir(): string
    {
        $dir = storage_path('app/tmp/uploads');
        if (! is_dir($dir)) {
            mkdir($dir, 0775, true);
        }

        return $dir;
    }

    private function partPath(string $id): string
    {
        return $this->dir() . DIRECTORY_SEPARATOR . $id . '.part';
    }

    private function metaPath(string $id): string
    {
        return $this->dir() . DIRECTORY_SEPARATOR . $id . '.json';
    }

    // Abandoned uploads would otherwise sit on disk forever.
    private function purgeStale(): void
    {
        foreach (glob($this->dir() . DIRECTORY_SEPARATOR . '*') ?: [] as $file) {
            if (is_file($file) && filemtime($file) < time() - 2 * 86400) {
                @unlink($file);
            }
        }
    }
}
