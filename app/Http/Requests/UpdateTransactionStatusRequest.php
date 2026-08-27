<?php

namespace App\Http\Requests;

use App\Models\Transaction;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class UpdateTransactionStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'status' => ['required', 'string', Rule::in(Transaction::STATUSES)],
        ];
    }

    /**
     * @return array<int, callable>
     */
    public function after(): array
    {
        return [
            function (Validator $validator): void {
                /** @var Transaction|null $transaction */
                $transaction = $this->route('transaction');
                $status = $this->string('status')->toString();

                if ($transaction && $status && ! $this->transitionIsAllowed($transaction->status, $status)) {
                    $validator->errors()->add('status', 'The selected status is not a valid transition.');
                }
            },
        ];
    }

    private function transitionIsAllowed(string $currentStatus, string $nextStatus): bool
    {
        return match ($currentStatus) {
            Transaction::STATUS_PENDING => $nextStatus === Transaction::STATUS_PROCESSING,
            Transaction::STATUS_PROCESSING => in_array($nextStatus, [
                Transaction::STATUS_SUCCESSFUL,
                Transaction::STATUS_FAILED,
            ], true),
            default => false,
        };
    }
}
