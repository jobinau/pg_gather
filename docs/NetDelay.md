# Net / Delay
[![Nework / Delay Explained](https://img.youtube.com/vi/v5Y9YT44rOY/0.jpg)](https://youtu.be/v5Y9YT44rOY)

Network or Delay. This is the time spent without doing anything. Waiting for something to happen. 
Common causes are:
1. **High network latency** 
 Not every "Network/Delay" won't always result in "ClientRead" because the network delay can affect select statements also, which are independent of the transaction block.
2. **Connection poolers/proxies**  
 Proxies standing in between the application server and the database can cause delays.
3. **Application design**  
If the Application becomes too chatty (Many back and forth communication), database sessions start spending more time waiting for communication.
4. **Application side processing time.**  
For example, An application executes a SELECT statement and receives a result set. Subsequently, a period of time may be required to process these results before the next statement is sent. This intermittent idling between transactions is also a factor to consider.
for this category.
5. **Overloaded servers** - Waiting for scheduling  
On an overloaded application or database server, processes spend more time waiting in the run queue to be executed, because run queue gets longer. This increased wait time is known as run "*queue latency*" or "*CPU contention*".  
Such waiting time also accounted in Net/Delay.
