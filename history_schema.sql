--DROP SCHEMA IF EXISTS history CASCADE;
CREATE SCHEMA IF NOT EXISTS history;

CREATE UNLOGGED TABLE IF NOT EXISTS history.pg_gather (
    imp_ts timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    collect_ts timestamp with time zone,
    usr text,
    db text,
    ver text,
    pg_start_ts timestamp with time zone,
    recovery bool,
    client inet,
    server inet,
    reload_ts timestamp with time zone,
    current_wal pg_lsn
);


CREATE UNLOGGED TABLE  IF NOT EXISTS  history.pg_get_activity (
    collect_ts timestamp with time zone,
    datid oid, 
    pid integer,
    usesysid oid,
    application_name text,
    state text,
    query text,
    wait_event_type text,
    wait_event text,
    xact_start timestamp with time zone,
    query_start timestamp with time zone,
    backend_start timestamp with time zone,
    state_change timestamp with time zone,
    client_addr inet,
    client_hostname text,
    client_port integer,
    backend_xid xid,
    backend_xmin xid,
    backend_type text,
    ssl boolean,
    sslversion text,
    sslcipher text,
    sslbits integer,
    sslcompression boolean,
    ssl_client_dn text,
    ssl_client_serial numeric,
    ssl_issuer_dn text,
    gss_auth boolean,
    gss_princ text,
    gss_enc boolean,
    leader_pid integer
);

CREATE UNLOGGED TABLE history.pg_pid_wait(
    collect_ts timestamp with time zone,
    itr SERIAL,
    pid integer,
    wait_event text
);


CREATE UNLOGGED TABLE history.pg_get_db (
    collect_ts timestamp with time zone,
    datid oid,
    datname text,
    xact_commit bigint,
    xact_rollback bigint,
    blks_fetch bigint,
    blks_hit bigint,
    tup_returned bigint,
    tup_fetched bigint,
    tup_inserted bigint,
    tup_updated bigint,
    tup_deleted bigint,
    temp_files bigint,
    temp_bytes bigint,
    deadlocks bigint,
    blk_read_time double precision,
    blk_write_time double precision,
    db_size bigint,
    age integer,
    stats_reset timestamp with time zone
);

CREATE UNLOGGED TABLE history.pg_get_block (
    collect_ts timestamp with time zone,
    blocked_pid integer,
    blocked_user text,
    blocked_client_addr text,
    blocked_client_hostname text,
    blocked_application_name text,
    blocked_wait_event_type text,
    blocked_wait_event text,
    blocked_statement text,
    blocked_xact_start timestamp with time zone,
    blocking_pid integer,
    blocking_user text,
    blocking_user_addr text,
    blocking_client_hostname text,
    blocking_application_name text,
    blocking_wait_event_type text,
    blocking_wait_event text,
    statement_in_blocking_process text,
    blocking_xact_start timestamp with time zone
);

CREATE UNLOGGED TABLE history.pg_replication_stat (
    collect_ts timestamp with time zone,
    usename text,
    client_addr text,
    client_hostname text,
    state text,
    sent_lsn pg_lsn,
    write_lsn pg_lsn,
    flush_lsn pg_lsn,
    replay_lsn pg_lsn,
    sync_state text
);

CREATE UNLOGGED TABLE history.pg_archiver_stat(
    collect_ts timestamp with time zone,
    archived_count bigint,
    last_archived_wal text,
    last_archived_time timestamp with time zone,
    last_failed_wal text,
    last_failed_time timestamp with time zone
);

CREATE UNLOGGED TABLE history.pg_get_bgwriter(
    collect_ts timestamp with time zone,
    checkpoints_timed bigint,
    checkpoints_req  bigint,
    checkpoint_write_time double precision,
    checkpoint_sync_time double precision,
    buffers_checkpoint bigint,
    buffers_clean bigint,
    maxwritten_clean bigint,
    buffers_backend bigint,
    buffers_backend_fsync bigint,
    buffers_alloc bigint,
    stats_reset timestamp with time zone
);