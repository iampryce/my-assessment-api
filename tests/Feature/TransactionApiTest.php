<?php

use App\Models\Transaction;

test('a transaction can be created', function () {
    $payload = [
        'customer_name' => 'Ada Okafor',
        'customer_email' => 'ada@example.com',
        'amount' => 125000,
        'currency' => 'ngn',
        'description' => 'Invoice payment',
    ];

    $response = $this->postJson('/api/v1/transactions', $payload)
        ->assertCreated()
        ->assertJsonPath('data.customer_name', 'Ada Okafor')
        ->assertJsonPath('data.customer_email', 'ada@example.com')
        ->assertJsonPath('data.amount', 125000)
        ->assertJsonPath('data.currency', 'NGN')
        ->assertJsonPath('data.status', Transaction::STATUS_PENDING)
        ->assertJsonStructure([
            'data' => [
                'id',
                'reference',
                'customer_name',
                'customer_email',
                'amount',
                'currency',
                'status',
                'description',
                'created_at',
                'updated_at',
            ],
        ]);

    expect($response->json('data.reference'))->toStartWith('TXN-');

    $this->assertDatabaseHas('transactions', [
        'customer_email' => 'ada@example.com',
        'amount' => 125000,
        'currency' => 'NGN',
        'status' => Transaction::STATUS_PENDING,
    ]);
});

test('transaction creation validates required and formatted fields', function (array $payload, string $field) {
    $this->postJson('/api/v1/transactions', $payload)
        ->assertUnprocessable()
        ->assertJsonValidationErrors($field);
})->with([
    'missing customer name' => [
        [
            'customer_email' => 'ada@example.com',
            'amount' => 125000,
            'currency' => 'NGN',
        ],
        'customer_name',
    ],
    'missing email' => [
        [
            'customer_name' => 'Ada Okafor',
            'amount' => 125000,
            'currency' => 'NGN',
        ],
        'customer_email',
    ],
    'invalid email' => [
        [
            'customer_name' => 'Ada Okafor',
            'customer_email' => 'not-an-email',
            'amount' => 125000,
            'currency' => 'NGN',
        ],
        'customer_email',
    ],
    'missing amount' => [
        [
            'customer_name' => 'Ada Okafor',
            'customer_email' => 'ada@example.com',
            'currency' => 'NGN',
        ],
        'amount',
    ],
    'zero amount' => [
        [
            'customer_name' => 'Ada Okafor',
            'customer_email' => 'ada@example.com',
            'amount' => 0,
            'currency' => 'NGN',
        ],
        'amount',
    ],
    'negative amount' => [
        [
            'customer_name' => 'Ada Okafor',
            'customer_email' => 'ada@example.com',
            'amount' => -1,
            'currency' => 'NGN',
        ],
        'amount',
    ],
    'missing currency' => [
        [
            'customer_name' => 'Ada Okafor',
            'customer_email' => 'ada@example.com',
            'amount' => 125000,
        ],
        'currency',
    ],
    'invalid currency' => [
        [
            'customer_name' => 'Ada Okafor',
            'customer_email' => 'ada@example.com',
            'amount' => 125000,
            'currency' => 'NGNA',
        ],
        'currency',
    ],
]);

test('transactions are listed with pagination metadata', function () {
    Transaction::factory()->count(3)->create();

    $this->getJson('/api/v1/transactions')
        ->assertOk()
        ->assertJsonCount(3, 'data')
        ->assertJsonStructure([
            'data',
            'links',
            'meta' => [
                'current_page',
                'last_page',
                'per_page',
                'total',
            ],
        ]);
});

test('transactions can be filtered by status', function () {
    Transaction::factory()->create(['status' => Transaction::STATUS_SUCCESSFUL]);
    Transaction::factory()->create(['status' => Transaction::STATUS_FAILED]);

    $this->getJson('/api/v1/transactions?status=successful')
        ->assertOk()
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.status', Transaction::STATUS_SUCCESSFUL);
});

test('invalid status filters are rejected', function () {
    $this->getJson('/api/v1/transactions?status=refunded')
        ->assertUnprocessable()
        ->assertJsonValidationErrors('status');
});

test('a transaction can be retrieved', function () {
    $transaction = Transaction::factory()->create();

    $this->getJson("/api/v1/transactions/{$transaction->id}")
        ->assertOk()
        ->assertJsonPath('data.id', $transaction->id)
        ->assertJsonPath('data.reference', $transaction->reference);
});

test('an unknown transaction returns not found', function () {
    $this->getJson('/api/v1/transactions/999999')
        ->assertNotFound();
});

test('valid status transitions are supported', function (string $initial, string $next) {
    $transaction = Transaction::factory()->create(['status' => $initial]);

    $this->patchJson("/api/v1/transactions/{$transaction->id}/status", [
        'status' => $next,
    ])
        ->assertOk()
        ->assertJsonPath('data.status', $next);

    $this->assertDatabaseHas('transactions', [
        'id' => $transaction->id,
        'status' => $next,
    ]);
})->with([
    'pending to processing' => [Transaction::STATUS_PENDING, Transaction::STATUS_PROCESSING],
    'processing to successful' => [Transaction::STATUS_PROCESSING, Transaction::STATUS_SUCCESSFUL],
    'processing to failed' => [Transaction::STATUS_PROCESSING, Transaction::STATUS_FAILED],
]);

test('unsupported statuses are rejected', function () {
    $transaction = Transaction::factory()->create(['status' => Transaction::STATUS_PROCESSING]);

    $this->patchJson("/api/v1/transactions/{$transaction->id}/status", [
        'status' => 'refunded',
    ])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('status');
});

test('unsupported status transitions are rejected', function () {
    $transaction = Transaction::factory()->create(['status' => Transaction::STATUS_PENDING]);

    $this->patchJson("/api/v1/transactions/{$transaction->id}/status", [
        'status' => Transaction::STATUS_SUCCESSFUL,
    ])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('status');
});

test('a transaction can be deleted', function () {
    $transaction = Transaction::factory()->create();

    $this->deleteJson("/api/v1/transactions/{$transaction->id}")
        ->assertNoContent();

    $this->assertDatabaseMissing('transactions', [
        'id' => $transaction->id,
    ]);
});
