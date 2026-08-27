#!/bin/sh
set -eu

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"

health_response="$(curl -fsS "$BASE_URL/api/v1/health")"
ready_response="$(curl -fsS "$BASE_URL/api/v1/ready")"

case "$health_response" in
    *'"status":"ok"'*) ;;
    *)
        echo "Health check failed: $health_response" >&2
        exit 1
        ;;
esac

case "$ready_response" in
    *'"status":"ready"'*'"database":"ok"'*) ;;
    *)
        echo "Readiness check failed: $ready_response" >&2
        exit 1
        ;;
esac

echo "Smoke checks passed for $BASE_URL"
