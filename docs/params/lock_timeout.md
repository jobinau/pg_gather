# lock_timeout

A session of indefinitely waiting for necessary locks needs to be avoided. Such sessions could appear to be hanging.
It is far better to cancel itself and come out reporting the problem.
A general suggestion is to wait a maximum of 1 minute to get the necessary locks.
```
ALTER SYSTEM SET lock_timeout = '1min';
```
