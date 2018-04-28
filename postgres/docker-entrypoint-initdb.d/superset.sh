#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username postgres <<-EOSQL
	CREATE USER superset;
	ALTER USER superset WITH PASSWORD '$POSTGRES_PASSWORD';
	CREATE DATABASE superset;
	GRANT ALL PRIVILEGES ON DATABASE superset TO superset;
EOSQL
