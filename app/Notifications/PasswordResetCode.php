<?php

namespace App\Notifications;

use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/** Kode 4 digit untuk mengganti sandi dari aplikasi mobile (lihat AuthController). */
class PasswordResetCode extends Notification
{
    public function __construct(public readonly string $code, public readonly int $minutes) {}

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('Kode reset kata sandi: '.$this->code)
            ->greeting('Halo '.$notifiable->name.',')
            ->line('Masukkan kode ini di aplikasi untuk membuat kata sandi baru:')
            ->line('**'.$this->code.'**')
            ->line("Kode berlaku {$this->minutes} menit. Kalau kamu tidak memintanya, abaikan email ini — sandimu tidak berubah.")
            ->salutation(config('app.name'));
    }
}
