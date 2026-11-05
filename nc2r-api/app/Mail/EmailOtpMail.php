<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class EmailOtpMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public string $code,
        public int $minutes,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: 'Your NC2R verification code');
    }

    public function content(): Content
    {
        return new Content(view: 'emails.otp');
    }
}
