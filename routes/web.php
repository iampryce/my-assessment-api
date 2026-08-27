<?php

use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/docs', function () {
    return view('docs');
});

Route::get('/openapi.yaml', function () {
    return response(File::get(base_path('openapi.yaml')), 200, [
        'Content-Type' => 'application/yaml',
    ]);
});
