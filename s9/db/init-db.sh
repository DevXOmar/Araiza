#!/usr/bin/env bash
set -euo pipefail
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set ON_ERROR_STOP=1 \
  --set role_name="$LAB_DB_USER" --set role_password="$LAB_DB_PASSWORD" <<'SQL'
CREATE ROLE :"role_name" LOGIN PASSWORD :'role_password';
GRANT CONNECT ON DATABASE :"DBNAME" TO :"role_name";
GRANT USAGE, CREATE ON SCHEMA public TO :"role_name";
SET ROLE :"role_name";
CREATE TABLE requests (reference VARCHAR(60) PRIMARY KEY, unit VARCHAR(30) NOT NULL);
SQL
