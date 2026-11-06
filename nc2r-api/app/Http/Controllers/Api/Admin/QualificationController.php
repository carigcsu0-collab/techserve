<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAuditLog;
use App\Models\Qualification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class QualificationController extends Controller
{
    public function index()
    {
        $qualifications = Qualification::query()
            ->withCount('lessons')
            ->orderBy('order_index')
            ->get()
            ->map(fn (Qualification $q) => $this->toApi($q));

        return response()->json(['qualifications' => $qualifications->values()]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate($this->rules());
        $validated['order_index'] ??= (int) Qualification::max('order_index') + 1;

        $qualification = Qualification::create($validated);
        AdminAuditLog::record($request->user(), 'qualification.created', "Created qualification \"{$qualification->title}\"", $qualification);

        return response()->json(['qualification' => $this->toApi($qualification->loadCount('lessons'))], 201);
    }

    public function update(Request $request, Qualification $qualification)
    {
        $validated = $request->validate($this->rules(sometimes: true));

        $qualification->update($validated);
        AdminAuditLog::record($request->user(), 'qualification.updated', "Updated qualification \"{$qualification->title}\"", $qualification);

        return response()->json(['qualification' => $this->toApi($qualification->fresh()->loadCount('lessons'))]);
    }

    public function destroy(Request $request, Qualification $qualification)
    {
        if ($qualification->lessons()->exists()) {
            return response()->json([
                'message' => 'Move or delete the lessons in this qualification first.',
            ], 422);
        }

        $title = $qualification->title;
        $qualification->delete();
        AdminAuditLog::record($request->user(), 'qualification.deleted', "Deleted qualification \"{$title}\"");

        return response()->json(['message' => 'Qualification deleted']);
    }

    // Same two-phase swap as lessons, so the unique order index never collides.
    public function reorder(Request $request)
    {
        $validated = $request->validate([
            'ids' => ['required', 'array', 'min:1'],
            'ids.*' => ['integer', 'distinct'],
        ]);

        $ids = $validated['ids'];
        $group = Qualification::query()->orderBy('order_index')->get(['id', 'order_index']);

        if (count($ids) !== $group->count() || array_diff($group->pluck('id')->all(), $ids) !== []) {
            return response()->json(['message' => 'Provide every qualification id exactly once.'], 422);
        }

        $slots = $group->pluck('order_index')->values()->all();

        DB::transaction(function () use ($ids, $slots) {
            foreach ($ids as $position => $id) {
                Qualification::whereKey($id)->update(['order_index' => -($position + 1)]);
            }
            foreach ($ids as $position => $id) {
                Qualification::whereKey($id)->update(['order_index' => $slots[$position]]);
            }
        });

        AdminAuditLog::record($request->user(), 'qualification.reordered', 'Reordered ' . count($ids) . ' qualifications');

        return response()->json(['message' => 'Qualifications reordered']);
    }

    private function rules(bool $sometimes = false): array
    {
        $prefix = $sometimes ? 'sometimes' : 'required';

        return [
            'title' => [$prefix, 'string', 'max:255'],
            'description' => [$prefix, 'string'],
            'order_index' => ['sometimes', 'integer', 'min:1'],
        ];
    }

    private function toApi(Qualification $qualification): array
    {
        return [
            'id' => $qualification->id,
            'title' => $qualification->title,
            'description' => $qualification->description,
            'order_index' => $qualification->order_index,
            'lesson_count' => $qualification->lessons_count ?? $qualification->lessons()->count(),
        ];
    }
}
