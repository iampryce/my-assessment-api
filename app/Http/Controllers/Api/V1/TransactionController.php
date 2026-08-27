<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreTransactionRequest;
use App\Http\Requests\UpdateTransactionStatusRequest;
use App\Http\Resources\TransactionResource;
use App\Models\Transaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Validation\Rule;

class TransactionController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        request()->validate([
            'status' => ['sometimes', 'string', Rule::in(Transaction::STATUSES)],
        ]);

        $transactions = Transaction::query()
            ->when(request('status'), fn ($query, string $status) => $query->where('status', $status))
            ->latest()
            ->paginate();

        return TransactionResource::collection($transactions);
    }

    public function store(StoreTransactionRequest $request): JsonResponse
    {
        $transaction = Transaction::query()->create($request->validated());

        return (new TransactionResource($transaction))
            ->response()
            ->setStatusCode(201);
    }

    public function show(Transaction $transaction): TransactionResource
    {
        return new TransactionResource($transaction);
    }

    public function updateStatus(UpdateTransactionStatusRequest $request, Transaction $transaction): TransactionResource
    {
        $transaction->update($request->validated());

        return new TransactionResource($transaction);
    }

    public function destroy(Transaction $transaction): Response
    {
        $transaction->delete();

        return response()->noContent();
    }
}
