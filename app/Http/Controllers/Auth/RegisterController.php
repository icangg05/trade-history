<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\RegisterRequest;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Inertia\Inertia;
use Inertia\Response;

class RegisterController extends Controller
{
    public function create(): Response
    {
        abort_if($this->closed(), 404);

        return Inertia::render('Register');
    }

    /** Tertutup atau tidak, RegisterRequest yang menjawab 404 lebih dulu. */
    public function store(RegisterRequest $request): RedirectResponse
    {
        Auth::login(User::create($request->account()));
        $request->session()->regenerate();

        return redirect()->route('accounts.index')
            ->with('success', 'Akun dibuat. Sekarang buat akun trading pertamamu.');
    }

    /** Tanpa REGISTER_TOKEN di .env, pendaftaran mandiri tidak dibuka. */
    private function closed(): bool
    {
        return blank(config('auth.register_token'));
    }
}
