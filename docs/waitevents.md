# PostgreSQL Wait Events
This page lists the major wait events which generally appears on pg_gather report and their implications  
Please refer to PostgreSQL documentation [here](https://www.postgresql.org/docs/current/monitoring-stats.html#WAIT-EVENT-ACTIVITY-TABLE) onwards for additional wait-events and details.

## BufferContent
Write sessions aquring lock on buffers. Happens when there is too much concurrency.
Solution: 
1. Reduce the number of connections. Multiplex large number of application connection over few database connections using transaction level pooling.
2. Reduce the size of the table (Archive / Purge) to fit in to memory
3. Partition the table.
4. Reduce the data integrity checks in the database side including foreign keys, check contraints and triggers

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
Waiting to read/hear from the client/application. Two reasons generally cause high values for this wait-event
### 1. Network : 
The communication channel between the database and the application/client may have low bandwith or high latency. For example, there could be too many network hops. Many of the Cloud, Virtualization, Containerization, Firewall, and Routing (sometimes multi-layer routing) are found to cause high network latency. Latency has nothing to do with network bandwidth. Even a very high bandwidth connection can have high latency and affect the database performance.  
   The network related waits within the trasactions are generally accounted as "ClientRead"
### 2. Application response: 
The application side might be taking too long to respond to the database. For example, a transaction in progress might not be sending a COMMIT or ROLLBACK fast enough after sending the DML to the database server. 

This "ClientRead" wait-event combined with "idle-in-transaction" can cause contention in the server. 

## Net/Delay*
This is the Time elapsed by the session without doing anything. Multiple things can cause this.
1. High network latency.  
Not every "Network/Delay" won't always result in "ClientRead" because the network delay can affect select statements also, which are independent of the transaction block. 
2. poolers/proxies 
Connection poolers/proxies standing in between the application server and the database can cause delays. 
3. Application design 
When the Application becomes too chatty, database sessions start spending more time waiting for communication. 
4. Processing time at application side 
For example, the Application sends the first SELECT statement, then takes a delay before sending the next SELECT statement. 
5. Overloaded servers - Waiting for scheduling 
OS scheduler can give only smaller chunk of time as the host machine gets overloaded. Moreover There could be significant delay between two schedules.  This leads to a situation that connection/session waiting for execution. 

## ClientWrite
Waiting to write data to client/application, Generally caused by application retriving large amount of data at ones.

## CPU
Time spend in the computation. Divide the wait event count by 2000 to get approximate CPU core saturation by PostgreSQL.

## DataFileRead
The page required is not there in the shared buffers and waiting to fetch it. High percentage of waits can indicate poor cacheing.

## transactionid
Session waiting for other session to complete the transaction. Session is blocked.
For example, Updating the same rows of a table from multiple sessions can lead to this situation.

## WALInsertLock
Consider increasing the `wal_buffers`. Upto 64MB max.

## WalReceiverMain
Receiver is waiting for new data to arrive

## WalReceiverWaitStart
Walreceiver is waiting for startup process to set the lsn and timeline

## WalSenderMain
WAL Sender process is just waiting in the main loop. Ignorable

## WalSenderWriteData  
Generally observed with Logical replication as the cause of replication lag.
This Waitevent indicates that the WAL sender process is waiting for sending the data because the socket is not ready. In other words, walsender has pending data in the output buffer and are waiting to write data to a client (subscriber)
This Could be due to high network latency or poor bandwidth.

## WalSenderWaitForWAL
WAL Sender process is waiting for the WAL to be flushed. The WAL sender sleeps for sometime and wakes up if scoket is available.
This wait-event is seen in logical replication.

## WalWriteLock
This is a lock to be held by a PostgreSQL process, if it need to write WAL buffers to disk (XLogWrite or XLogFlush).  
Big value indicates large number of process trying to do heavy writing to WAL. 
Suggessions:
Have a high bandwith, low latency storage for pg_wal directory
Avoid `wal_level = logical` unless it is essentail.
Improve the connection pooling there by reduce the connections.
Automatic vacuum after Bulk data loading can cause this. So add a supplimentory `VACUUM (FREEZE,ANALYZE) TBL` also on the table bulk data loading is performed.
