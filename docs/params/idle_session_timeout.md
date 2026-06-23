# idle_session_timeout

This is one of the dangerous settings and is often misused because of a misunderstanding.

In any database, it is quite normal to see idle sessions; it is not something bad. Connection poolers keep a lot of pre-established connections, which appear as idle connections. Applications and drivers also maintain their own connection pools the same way.

`idle_session_timeout` terminates any session that stays idle longer than the specified time, **regardless of whether it is inside a transaction**. This is very different from [idle_in_transaction_session_timeout](idle_in_transaction_session_timeout.md), which only targets sessions that hold an open transaction while sitting idle — those are genuinely harmful and should be timed out.

Terminating plain idle connections without the consent of the connection pooler or the application on the other end can have serious consequences. The pooler or application may not expect the connection to disappear, leading to errors, reconnection storms, and unnecessary load.

This setting can affect backups as well. Backup tools that keep a dedicated database session open (for example, while waiting on long-running operations) can have that session terminated mid-backup, causing the backup to fail. See [pgbackrest issue #2789](https://github.com/pgbackrest/pgbackrest/issues/2789) for a real-world example.

It is highly recommended to leave this parameter at its default value (`0`) so that idle sessions are not terminated.
```
ALTER SYSTEM SET idle_session_timeout = 0;
```

If the use of `idle_session_timeout` is unavoidable for some reason, it is highly recommended to set it to at least 30 minutes to 1 hour, so that legitimate pooled and application connections are not disrupted.
```
ALTER SYSTEM SET idle_session_timeout = '30min';
```

For more on why this setting can be a bad idea, see: [Human Factors Behind Incidents: Why Settings Like idle_session_timeout Can Be a Bad Idea](https://www.percona.com/blog/human-factors-behind-incidents-why-settings-like-idle_session_timeout-can-be-a-bad-idea/)
