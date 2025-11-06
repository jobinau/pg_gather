# wal_recycle
If set to `on` (the default), this option causes WAL files to be recycled by renaming them, avoiding the need to create new ones. On CoW file systems like ZFS / BTRFS, it may be faster to create new ones, so the option is given to disable this behavior.

## Reference
* [feature commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commitdiff;h=475861b26)
* [Discussions 1](https://www.postgresql.org/message-id/flat/CACPQ5Fo00QR7LNAcd1ZjgoBi4y97%2BK760YABs0vQHH5dLdkkMA%40mail.gmail.com)
