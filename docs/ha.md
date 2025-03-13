# High Availability in PostgreSQL
High Availability of PostgreSQL is generally implemented as an external framework.  
[Patroni](https://github.com/patroni/patroni), [RepMgr](https://github.com/EnterpriseDB/repmgr) , [Stolon](https://github.com/sorintlab/stolon) and [pg_auto_failover](https://github.com/hapostgres/pg_auto_failover) are some of the commonly considered OpenSource HA Frameworks.

Unfortunately, the feedback from the production use of some of the frameworks is not great. Some frameworks are reported to cause more problems and reliability issues, resulting in more outages and unavailability.
Some of the frameworks cause more split-brain incidents, which is considered as one of the most dangerous thing that can happen to a database system.

Please consider the following important criteria while evaluating and selecting HA frameworks.

1. Protection from Network Partitioning  
 The network is one of the most unreliable parts of a cluster. There sould be good algorithms like [`Raft`](https://en.wikipedia.org/wiki/Raft_(algorithm)) or [`Paxos`](https://en.wikipedia.org/wiki/Paxos_(computer_science)) to handle such events.
2. Protection from Split-brain.  
 As mentioned above, a reliable algorithm will provide the first line of protection. However, in case of network isolation, where there is no way to know the truth, the framework should take the PostgreSQL instance to read-only mode to protect against Split Brain. This acts as the second line of protection.
3. Maintain the topology integrity  
The HA framework should make sure that there is only one leader at a time at any cost and reconfigure the topology to maintain this integrity
4. STONITH / fencing.  
In extreme cases of node hangs, the framework should be capable of STONITH/fencing. Integration with Linux Watchdog is highly recommended. This is the last and highest level of protection.
5. Central management of configuration.  
HA is all about avoiding single point of failures. So Idealy, there shouldn't be any special nodes in a cluster. The HA Framework should ensure that all necessary parameters are same accross all the nodes, so that there won't be a surprise after a switchover or failover.
6. Ability to manage cluster without any extension.  
 Avoid extensions as much as possible. Especially those that store data in local nodes.
7. Something which passed the test of time.  
 HA frameworks are something which needs to be proven its credibility over time. Getting a wider community feedback is highly suggestable. Reliability / trustability is something to be proven over a period of time. Avoid taking risks.
8. Auto detection of failures and actions.  
 Not just node failure, but topology failure also need to be detected and necessary action should be performed including rewind or reinit. 
9. Simple and reliable interface for DBAs  
 HA framework should provide a simple experience to perform manual switchovers and reinitialize and rejoin a lost node

## Recommendation
Currently, [Patroni](https://github.com/patroni/patroni) is considered the best HA Project, meeting the majority of the requirements of a HA solution  
(Hint: Please consider the Github star ratings and Number of commits to understand the popularity and rate of development)




