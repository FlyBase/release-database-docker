-- scripts/init/01-create-flybase-role.sql
-- Runs once when initdb.d processes a fresh data directory.
-- Creates the flybase role/database, grants table-data SELECT, and locks down
-- everything else so the flybase login is strictly read-only at the server
-- level (no temp tables, no schema creation, no new databases).

CREATE ROLE flybase WITH LOGIN NOCREATEDB NOCREATEROLE;

CREATE DATABASE flybase OWNER flybase;

-- Lock down database-level CREATE/TEMP. The flybase user can still CONNECT
-- (it's the database owner, which implicitly grants CONNECT) but cannot
-- create schemas, temp tables, or anything else here.
REVOKE CREATE, TEMP ON DATABASE flybase FROM PUBLIC;
REVOKE CREATE, TEMP ON DATABASE flybase FROM flybase;

\connect flybase

-- New objects created by postgres in the public schema grant SELECT to flybase.
-- This enforces read-only access for the flybase user when the dump loads tables
-- (the dump's CREATE TABLE statements run as the postgres connecting user).
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT SELECT ON TABLES TO flybase;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT SELECT ON SEQUENCES TO flybase;

-- Grant USAGE on public schema (matches existing production)
GRANT USAGE ON SCHEMA public TO flybase;

-- Database-level REVOKE only stops CREATE SCHEMA + TEMP. In PostgreSQL the
-- built-in `public` schema grants CREATE to PUBLIC by default, which would
-- let the flybase user CREATE TABLE in it. Revoke that separately so the
-- role really is read-only.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM flybase;
