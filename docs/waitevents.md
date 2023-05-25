# PostgreSQL Wait Events
This page lists the major wait events which generally appears on pg_gather report and their implications  
Please refer to PostgreSQL documentation [here](https://www.postgresql.org/docs/current/monitoring-stats.html#WAIT-EVENT-ACTIVITY-TABLE) onwards for additional wait-events and details.

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
Network / Delay won't always result in "ClientRead", because the network delay can affect select statements also, which are indepent of transaction block.
This is the estimate of each session wasting its time waiting for communication outside a transaction block.

## ClientWrite
Waiting to write data to client/application, Generally caused by application retriving large amount of data at ones.

## CPU
Time spend in the computation. Divide the wait event count by 2000 to get approximate CPU core saturation by PostgreSQL.

## DataFileRead
The page required is not there in the shared buffers and waiting to fetch it. High percentage of waits can indicate poor cacheing.

## WalSenderMain
WAL Sender process is just waiting in the main loop. Ignorable

## WalSenderWaitForWAL
WAL Sender process is waiting for the WAL to be flushed. The WAL sender sleeps for sometime and wakes up if scoket is available.
This wait-event is seen in logical replication.

