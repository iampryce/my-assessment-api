<?php

namespace App\Models;

use Database\Factories\TransactionFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

#[Fillable([
    'reference',
    'customer_name',
    'customer_email',
    'amount',
    'currency',
    'status',
    'description',
])]
class Transaction extends Model
{
    /** @use HasFactory<TransactionFactory> */
    use HasFactory;

    public const STATUS_PENDING = 'pending';

    public const STATUS_PROCESSING = 'processing';

    public const STATUS_SUCCESSFUL = 'successful';

    public const STATUS_FAILED = 'failed';

    public const STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_PROCESSING,
        self::STATUS_SUCCESSFUL,
        self::STATUS_FAILED,
    ];

    protected $attributes = [
        'status' => self::STATUS_PENDING,
    ];

    protected static function booted(): void
    {
        static::creating(function (Transaction $transaction): void {
            if (! $transaction->reference) {
                $transaction->reference = self::generateReference();
            }
        });

        static::saving(function (Transaction $transaction): void {
            if ($transaction->currency) {
                $transaction->currency = strtoupper($transaction->currency);
            }
        });
    }

    public static function generateReference(): string
    {
        do {
            $reference = 'TXN-'.Str::upper(Str::random(12));
        } while (self::query()->where('reference', $reference)->exists());

        return $reference;
    }

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'amount' => 'integer',
        ];
    }
}
