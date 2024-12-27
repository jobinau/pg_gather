# Netowrk OR Delay
[![Nework / Delay Explained](https://img.youtube.com/vi/v5Y9YT44rOY/0.jpg)](https://youtu.be/v5Y9YT44rOY)

Network or Delay. This is the time spent without doing anything. Waiting for something to happen. 
Common causes are:
1. High network latency. 
 Not every "Network/Delay" won't always result in "ClientRead" because the network delay can affect select statements also, which are independent of the transaction block.
2. Connection poolers/proxies standing in between the application server and the database can cause delays.
3. Application design, which results in too much back-and-forth communication.  
 When the Application becomes too chatty, database sessions start spending more time waiting for communication.
4. Application side processing time.
 For example, the Application sends the first SELECT statement, then takes a delay before sending the next SELECT statement.
5. Overloaded servers - Waiting for scheduling
 When application server or database server gets overloaded, process will spend higher time waiting for OS scheduler to execute it.
 Such waiting for scheduler action is also counted in Net/Delay.
