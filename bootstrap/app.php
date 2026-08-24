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

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
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
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
