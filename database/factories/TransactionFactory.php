<?php

namespace Database\Factories;

use App\Models\Transaction;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Transaction>
 */
class TransactionFactory extends Factory
{
    protected $model = Transaction::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'reference' => 'TXN-'.$this->faker->unique()->regexify('[A-Z0-9]{12}'),
            'customer_name' => $this->faker->name(),
            'customer_email' => $this->faker->unique()->safeEmail(),
            'amount' => $this->faker->numberBetween(100, 2_500_000),
            'currency' => $this->faker->randomElement(['NGN', 'USD', 'GBP']),
            'status' => $this->faker->randomElement(Transaction::STATUSES),
            'description' => $this->faker->optional()->sentence(),
        ];
    }
}
