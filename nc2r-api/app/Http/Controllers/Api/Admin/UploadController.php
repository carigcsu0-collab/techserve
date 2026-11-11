<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Services\ChunkedUpload;
use Illuminate\Http\Request;

class UploadController extends Controller
{
    public function __construct(private ChunkedUpload $uploads) {}

    public function start(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'size' => ['required', 'integer', 'min:1', 'max:' . ChunkedUpload::MAX_BYTES],
        ]);

        return response()->json([
            'upload_id' => $this->uploads->begin($request->user(), $validated['name'], (int) $validated['size']),
        ], 201);
    }

    public function chunk(Request $request, string $id)
    {
        $validated = $request->validate([
            'offset' => ['required', 'integer', 'min:0'],
            'chunk' => ['required', 'file', 'max:' . intdiv(ChunkedUpload::MAX_CHUNK_BYTES, 1024)],
        ]);

        $received = $this->uploads->append(
            $request->user(),
            $id,
            (int) $validated['offset'],
            $request->file('chunk')
        );

        return response()->json(['received' => $received]);
    }
}
