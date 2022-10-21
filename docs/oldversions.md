# pg_gather (pgGather) support for old PostgreSQL versions.
pgGather development considers mainly the PostgreSQL versions starting from 10.
But still it is possible to collect and analyze data from older versions.

## Challenge
The amount of information available from views like `pg_stat_activity` is significantly changed over versions. Ensuring backward compatibility with PostgreSQL version 9.6 and older, without sacrificing features is a tough task. Another challenge is that `psql` utility of older versions don't have sufficient feautre for data collection after the detection of the PostgreSQL version without any additional overhead.

However, The project is striving hard to ensure the minimum support for older versions. 

## Errors while collecting data
Please expect error messages while collecting the data. This is because old versions don't have many features, performance views, columns etc which the script is looking for. However, `pg_gather` is envisioned to handle failure scenarios, collect the possible data, and work using the same.
So you may just ignore the error messages and proceed.


## How to handle Errors while importing data.
Due to missing features in old `psql` versions, there could be multiple lines as follows in the output file (The out.txt where the data is collected)
```
COPY pg_get_activity (datid, pid ,usesysid ,application_name ,state ,query ,wait_event_type ,wait_event ,xact_start ,query_start ,backend_start ,state_change ,client_addr, client_hostname, client_port, backend_xid ,backend_xmin, backend_type,ssl ,sslversion ,sslcipher ,sslbits ,ssl_client_dn ,ssl_client_serial,ssl_issuer_dn ,gss_auth ,gss_princ ,gss_enc,leader_pid,query_id) FROM stdin;
COPY pg_get_activity (datid, pid ,usesysid ,application_name ,state ,query ,wait_event_type ,wait_event ,xact_start ,query_start ,backend_start ,state_change ,client_addr, client_hostname, client_port, backend_xid ,backend_xmin, backend_type,ssl ,sslversion ,sslcipher ,sslbits ,sslcompression ,ssl_client_dn ,ssl_client_serial,ssl_issuer_dn ,gss_auth ,gss_princ ,gss_enc,leader_pid) FROM stdin;
COPY pg_get_activity (datid, pid ,usesysid ,application_name ,state ,query ,wait_event_type ,wait_event ,xact_start ,query_start ,backend_start ,state_change ,client_addr, client_hostname, client_port, backend_xid ,backend_xmin, backend_type,ssl ,sslversion ,sslcipher ,sslbits ,sslcompression ,ssl_client_dn ,ssl_client_serial,ssl_issuer_dn ,gss_auth ,gss_princ ,gss_enc) FROM stdin;
COPY pg_get_activity (datid, pid ,usesysid ,application_name ,state ,query ,wait_event_type ,wait_event ,xact_start ,query_start ,backend_start ,state_change ,client_addr, client_hostname, client_port, backend_xid ,backend_xmin, backend_type,ssl ,sslversion ,sslcipher ,sslbits ,sslcompression ,ssl_client_dn ) FROM stdin;
```
These duplicate lines, which are not relevant for the old versions, can cause errors while importing the data.
All these duplicate lines (multiple lines) need to be replaced with a single line according to the data available for the particular PG version. Following are the samples for few PG versions
#### PostgreSQL 9.6
```
COPY pg_get_activity (datid,pid,usesysid,application_name,state,query,wait_event_type,wait_event,xact_start,query_start,backend_start,state_change,client_addr,client_hostname,client_port,backend_xid,backend_xmin,ssl,sslversion,sslcipher,sslbits,sslcompression,ssl_client_dn ) FROM stdin;
```
#### PostgreSQL 9.5
```
COPY pg_get_activity (datid,pid,usesysid,application_name,state,query,wait_event_type,xact_start,query_start,backend_start,state_change,client_addr,client_hostname,client_port,backend_xid,backend_xmin,ssl,sslversion,sslcipher,sslbits,sslcompression,ssl_client_dn ) FROM stdin;
```
#### PostgreSQL 9.2
```
COPY pg_get_activity (datid,pid,usesysid,application_name,state,query,wait_event_type,xact_start,query_start,backend_start,state_change,client_addr,client_hostname,client_port ) FROM stdin;
```
## Additional note
if you are using a specific version of PG,  you may please use a query as follows to understand the columns involved
```
select * from  pg_stat_get_activity(NULL) limit 0;
```
Additional contributions are welcome, and please raise [issue](https://github.com/jobinau/pg_gather/issues) if something is not working.
