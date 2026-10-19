-- Privilege check for issue #2's "Done when". Run as postgres after apply and
-- pii_key.sql; it switches to each role with SET ROLE, so no role passwords are
-- needed. Everything runs in one transaction that is rolled back.
-- Prints "all privilege checks passed" or stops at the first failure.
--
-- psql -f terraform/check_privileges.sql
\set ON_ERROR_STOP on
begin;

-- loader: writes raw_*, nothing else.
set role loader;
create table raw_wordpress_vitlamdata.check_raw (id int);
create table raw_metabase.check_raw (id int);
create table raw_sheets.check_raw (id int);
do $$ begin
    begin
        create table staging.check_loader (id int);
        raise exception 'FAIL: loader can create in staging';
    exception when insufficient_privilege then null;
    end;
end $$;
reset role;

-- transformer: reads raw_* and private.pii_key, cannot write raw_*, hashes.
set role transformer;
select from raw_wordpress_vitlamdata.check_raw, raw_metabase.check_raw, raw_sheets.check_raw;
select encode(hmac('x', (select key from private.pii_key), 'sha256'), 'hex') as hmac_as_transformer;
create table staging.check_transformer (id int);
do $$ begin
    begin
        insert into raw_wordpress_vitlamdata.check_raw values (1);
        raise exception 'FAIL: transformer can write raw_wordpress_vitlamdata';
    exception when insufficient_privilege then null;
    end;
    begin
        create table raw_wordpress_vitlamdata.check_transformer (id int);
        raise exception 'FAIL: transformer can create in raw_wordpress_vitlamdata';
    exception when insufficient_privilege then null;
    end;
end $$;
reset role;

-- developer, through ci: creates its own schema, reads prod (including the table
-- transformer created above: default privileges), cannot write prod.
set role ci;
create schema ci_pr_0_check;
create table ci_pr_0_check.t as select 1 as id;
select from raw_wordpress_vitlamdata.check_raw, staging.check_transformer;
select encode(hmac('x', (select key from private.pii_key), 'sha256'), 'hex') as hmac_as_ci;
do $$ begin
    begin
        insert into staging.check_transformer values (1);
        raise exception 'FAIL: developer can write staging';
    exception when insufficient_privilege then null;
    end;
    begin
        create table staging.check_ci (id int);
        raise exception 'FAIL: developer can create in staging';
    exception when insufficient_privilege then null;
    end;
    begin
        insert into raw_wordpress_vitlamdata.check_raw values (1);
        raise exception 'FAIL: developer can write raw_wordpress_vitlamdata';
    exception when insufficient_privilege then null;
    end;
end $$;
reset role;

-- reporter_public: can connect, sees no tables.
do $$ begin
    if not has_database_privilege('reporter_public', current_database(), 'CONNECT') then
        raise exception 'FAIL: reporter_public cannot connect';
    end if;
end $$;
set role reporter_public;
do $$ declare n int; begin
    select count(*) into n from information_schema.tables
    where table_schema not in ('pg_catalog', 'information_schema');
    if n > 0 then
        raise exception 'FAIL: reporter_public sees % tables', n;
    end if;
end $$;
reset role;

rollback;
\echo all privilege checks passed
