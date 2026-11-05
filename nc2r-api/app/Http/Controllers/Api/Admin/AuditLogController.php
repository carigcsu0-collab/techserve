<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAuditLog;
use Illuminate\Http\Request;

class AuditLogController extends Controller
{
    public function index(Request $request)
    {
        $logs = AdminAuditLog::with('admin:id,name')
            ->when($request->filled('before'), fn ($q) => $q->where('id', '<', (int) $request->query('before')))
            ->latest('id')
            ->limit(30)
            ->get();

        return response()->json([
            'logs' => $logs->map(fn (AdminAuditLog $log) => $log->toApi())->values(),
            'next_before' => $logs->count() === 30 ? $logs->last()->id : null,
        ]);
    }
}
