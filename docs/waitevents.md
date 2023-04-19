# PostgreSQL Wait Events
This page lists the major wait events and their implications
Always refer to PostgreSQL documentation [here](https://www.postgresql.org/docs/current/monitoring-stats.html#WAIT-EVENT-ACTIVITY-TABLE) onwards

## BufferIO
buffer I/O. Backends will be trying to clear the Buffers. High value indicates that there is not sufficient `shared_buffers`. Generally it is expected to have assoicated `DataFileRead` also

## BufferMapping
This indicates the heavy activity in shared_buffers. Loading or removing pages from shared_buffers requires exclusive lock on the page. Each session also can put a shared lock on the page.
High BufferMapping can indicate that big working-set-of-data by each session which the system is struggling to accomodate. Excesssive indexes and bloated indexes and unpartitioned huge tables are the common reasons.

## BufferPin
An open cursor or frequent HOT updates could be holding BufferPins on Buffer pages. Buffer pinning can prevent VACUUM FREEZE operation on those pages.

## BufFileRead
Reading from buffered Temporary Files, All sorts of temporary files including the one used for sort and hashjoins, parallel execution, And files used by single sessions (refer: buffile.c)

## ClientRead
Waiting to read data from the client/application. High value indcates that application/client is responding fast enough. combined with "idle-in-transaction" can cause contention in the server.

## ClientWrite
Waiting to write data to client/application, Generally caused by application retriving large amount of data at ones.

## CPU
Time spend in the computation. Divide the wait event count by 2000 to get approximate CPU core saturation by PostgreSQL.

## DataFileRead
The page required is not there in the shared buffers and waiting to fetch it. High percentage of waits can indicate poor cacheing.

## WalSenderMain
The WAL Senders are just waiting in the main loop. Ignorable

