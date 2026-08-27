<?php

use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\ReadinessController;
use App\Http\Controllers\Api\V1\TransactionController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('health', HealthController::class);
    Route::get('ready', ReadinessController::class);

    Route::apiResource('transactions', TransactionController::class)
        ->only(['index', 'store', 'show', 'destroy']);
    Route::patch('transactions/{transaction}/status', [TransactionController::class, 'updateStatus']);
});
