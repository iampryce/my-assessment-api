#!/bin/sh
set -eu

mkdir -p database storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache

if [ "${DB_CONNECTION:-sqlite}" = "sqlite" ]; then
    DB_PATH="${DB_DATABASE:-/app/database/database.sqlite}"

    case "$DB_PATH" in
        :memory:) ;;
        /*)
            mkdir -p "$(dirname "$DB_PATH")"
            touch "$DB_PATH"
            ;;
        *)
            mkdir -p "$(dirname "/app/$DB_PATH")"
            touch "/app/$DB_PATH"
            ;;
    esac
fi

exec "$@"
