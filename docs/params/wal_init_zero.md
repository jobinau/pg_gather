# wal_init_zero
If set to `on` (the default), this option causes new WAL files to be filled with zeroes. On some file systems, this ensures that space is allocated before we need to write WAL records. However, Copy-On-Write (COW) file systems may not benefit from this technique, so the option is given to skip the unnecessary work. If set to `off`

On the other hand turning it `off` on regular filesystems could cause performance regressions. Because when wal_init_zero  is off, PostgreSQL creates new WAL segments by simply `lseek`ing to the end of the file or using `fallocate()` without actually writing data to zero out the underlying blocks. On many common filesystems (like ext4/xfs), this creates "holes" in the file. When data is subsequently written to these "holey" blocks, the filesystem has to perform additional work, resulting in multiple disk operations.

## Reference
* [feature commit](https://git.postgresql.org/gitweb/?p=postgresql.git;a=commitdiff;h=475861b26)
* [Discussions 1](https://www.postgresql.org/message-id/flat/CACPQ5Fo00QR7LNAcd1ZjgoBi4y97%2BK760YABs0vQHH5dLdkkMA%40mail.gmail.com)
* [Discussions 2](https://www.postgresql.org/message-id/flat/87a5bs5tla.fsf%40163.com)