#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE naijagistdb;
    CREATE DATABASE authdb;
    GRANT ALL PRIVILEGES ON DATABASE naijagistdb TO $POSTGRES_USER;
    GRANT ALL PRIVILEGES ON DATABASE authdb TO $POSTGRES_USER;
EOSQL

echo "Databases naijagistdb and authdb created."
