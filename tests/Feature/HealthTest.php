<?php

test('health endpoint returns ok', function () {
    $this->getJson('/api/v1/health')
        ->assertOk()
        ->assertExactJson([
            'status' => 'ok',
        ]);
});

test('readiness endpoint verifies database access', function () {
    $this->getJson('/api/v1/ready')
        ->assertOk()
        ->assertExactJson([
            'status' => 'ready',
            'database' => 'ok',
        ]);
});

test('openapi specification is publicly accessible', function () {
    $this->get('/openapi.yaml')
        ->assertOk()
        ->assertHeader('content-type', 'application/yaml')
        ->assertSee('openapi: 3.1.0', false)
        ->assertSee('CashOnRails Assessment API', false);
});

test('swagger ui documentation is publicly accessible', function () {
    $this->get('/docs')
        ->assertOk()
        ->assertSee('CashOnRails Assessment API Docs', false)
        ->assertSee('/openapi.yaml', false)
        ->assertSee('SwaggerUIBundle', false);
});
