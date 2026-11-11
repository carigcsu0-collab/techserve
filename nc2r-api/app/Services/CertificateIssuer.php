<?php

namespace App\Services;

use App\Models\User;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Support\Facades\Storage;

class CertificateIssuer
{
    /**
     * Generate the learner's certificate once; returns the existing URL if present.
     */
    public function issue(User $user): string
    {
        if ($user->certificate_url !== null) {
            return $user->certificate_url;
        }

        $path = "certificates/certificate-{$user->id}.pdf";

        $pdf = Pdf::loadView('certificate', [
            'name' => $user->name,
            'course' => 'NC II Reviewer — Computer Systems Servicing',
            'date' => now()->format('F d, Y'),
            'certificateId' => sprintf('NC2R-%06d-%s', $user->id, now()->format('Y')),
        ])->setPaper('a4', 'landscape');

        Storage::disk('public')->put($path, $pdf->output());

        $url = asset("storage/{$path}");
        $user->update(['certificate_url' => $url]);

        return $url;
    }
}
