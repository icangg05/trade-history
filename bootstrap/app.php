<?php

use App\Http\Middleware\EnsureAdmin;
use App\Http\Middleware\EnsureTrader;
use App\Http\Middleware\HandleInertiaRequests;
use App\Http\Middleware\RequireAccount;
use App\Http\Middleware\SetCurrentAccount;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Routing\Exceptions\InvalidSignatureException;
use Inertia\Inertia;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Di produksi aplikasi berjalan di balik nginx (port kontainer hanya
        // terikat ke 127.0.0.1), jadi X-Forwarded-Proto dari proxy itu satu-
        // satunya cara Laravel tahu request aslinya https. Tanpa ini redirect
        // setelah POST lahir sebagai http:// dan diblokir browser sebagai
        // mixed content.
        $middleware->trustProxies(at: '*');

        $middleware->web(append: [
            SetCurrentAccount::class,
            HandleInertiaRequests::class,
        ]);

        $middleware->alias([
            'account' => RequireAccount::class,
            'admin' => EnsureAdmin::class,
            'trader' => EnsureTrader::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Tanda tangan yang kedaluwarsa atau diutak-atik dijawab 404, bukan 403.
        // Bagi yang membuka, tautan yang sudah mati dan berkas yang memang tidak
        // ada sama saja — dan jawaban itu tidak menegaskan barisnya benar ada.
        $exceptions->map(fn (InvalidSignatureException $e) => new NotFoundHttpException(previous: $e));

        $wantsJson = fn (Request $request) => $request->is('api/*') || $request->expectsJson();

        $exceptions->shouldRenderJsonWhen($wantsJson);

        /**
         * Halaman galat memakai tampilan aplikasi sendiri, bukan halaman putih
         * bawaan Symfony. Dua hal tetap dilewatkan apa adanya: permintaan yang
         * meminta JSON, dan galat server saat mode debug menyala — jejak galat
         * Laravel jauh lebih berguna daripada halaman yang rapi.
         */
        $exceptions->respond(function (Response $response, Throwable $e, Request $request) use ($wantsJson) {
            $status = $response->getStatusCode();

            if ($wantsJson($request) || ($status === 500 && config('app.debug'))) {
                return $response;
            }

            if (! in_array($status, [403, 404, 419, 429, 500, 503], true)) {
                return $response;
            }

            return Inertia::render('Error', ['status' => $status])
                ->toResponse($request)
                ->setStatusCode($status);
        });
    })->create();
