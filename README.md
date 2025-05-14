# `pg_gather` also known as pgGather

![pgGather logo](./docs/pgGather.svg)

`pg_gather` is an extension designed to collect and analyze test results from PostgreSQL test runs, it is especially useful for:

* Gathering results from TAP test frameworks
* Visualizing test coverage and failure rates
* Supporting regression or fuzz testing environments

You can use the following scripts:
  
* `gather.sql`, which gathers performance and configuration data from PostgreSQL databases.
* `gather_report.sql`, which analyzes the collected data and generates detailed HTML reports.

!!! note
    The project is built using psql, the native command-line interface for PostgreSQL, and relies solely on SQL features.

**Supported PostgreSQL Versions**: 10, 11, 12, 13, 14, 15, 16 & 17.
**Older versions**: For PostgeSQL versions 9.6 or older, refer to the [documentation page](docs/oldversions.md).

## `pg_gather` Highlights

1. **Security Through Transparency:**

   Simple, transparent, with a fully auditable code. `pg_gather` ensures full transparency of what is collected, transmitted, and analyzed. It uses an SQL-only data collection script and avoids programs with any enforced control structures, improving the readability and auditability of the data collection. This is one reason for separating data collection and analysis.

2. **Executable-free design**

   No executables need to be deployed on the database host. `pg_gather` does not require any other additional executables or libraries on the database host other than `psql`, this avoids the risk of deploying binaries in secured environments.

3. **Authentication compatibility**

   Any authentication mechanism supported by PostgreSQL works for data gathering in `pg_gather`, because it uses the standard `psql` command-line utility.

4. **Operating System compatibility**

   `pg_gather` ensures portability and compatibility among the following OS's: Linux (32/64-bit), Sun Solaris, Apple macOS, and Microsoft Windows.
   !!! note
      For Windows users, see the [Notes section](#notes) below.

5. **Architecture compatibility**

   `pg_gather` ensures compatibility with the following architectures: x86-64 bit, ARM, Sparc, Power, and more.

6. **Auditable and optionally maskable data**

   `pg_gather` collects data in the Tab Separated Values (TSV) format. This makes it easy to review and audit the information before sharing it for analysis. Additional masking or trimming is also possible with [the following simple steps](docs/security.md).

7. **Cloud-native compatibility**

   `pg_gather` works seamlessly with AWS RDS, Azure Database for PostgreSQL, Google Cloud SQL, on-premises PostgreSQL, and more.

   !!! note
      For details about Heroku, AWS Aurora, Docker and Kubernetes support see the [Notes section](#notes).

8. **Resilient by design**

   `pg_gather` is designed to generate reports even when some data collection fails, due to permission issues, missing views, or other runtime limitations. It collects as much information as possible without interrupting execution.

9. **Low overhead for data collection**

   By design, data collection is separate from data analysis. This allows the collected data to be analyzed on an independent system, so that analysis queries do not adversely impact critical systems. In most cases, the overhead of data collection is negligible.

10. **Compact by design**

   `pg_gather` minimizes data redundancy and generates a compact output file, which can be further compressed with `gzip` for more efficient transmission and storage.

## How to Use `pg_gather`

* 1. Use data gathering functions:

To gather configuration and performance information, run the `gather.sql` script against the database using `psql`:

```
psql <connection_parameters_if_any> -X -f gather.sql > out.tsv
```

OR pipe to a compression utilty to get a compressed output:

```
psql <connection_parameters_if_any> -X -f gather.sql | gzip > out.tsv.gz
```

This script may take over 20 seconds to run because it contains sleeps and delays. We recommend running the script as a privileged user (such as `superuser` or `rds_superuser`) or as an account with the `pg_monitor` privilege. The output file contains performance and configuration data ready for analysis.

### Additional details

* **Heroku** and similar DaaS hostings:

These impose very high restrictions on collecting performance data. Queries on views like `pg_statistics` may produce errors during data collection, however you can ignore these.

* **MS Windows** users:

Client tools like [pgAdmin](https://www.pgadmin.org/) include `psql`, which can be used to run `pg_gather` against local or remote databases.
For example:

```
"C:\Program Files\pgAdmin 4\v4\runtime\psql.exe" -h pghost -U postgres -f gather.sql > out.tsv
```

* **AWS Aurora** offers a "PostgreSQL-compatible" database. However, it is not a *true* PostgreSQL database. Therefore, do the following to the `gather.sql` script to replace any unapplicable lines with *NULL*.

```
sed -i -e 's/^CASE WHEN pg_is_in_recovery().*/NULL/' gather.sql
```

* **Docker** containers of PostgreSQL may not include the `curl` or `wget` utilities necessary to download `gather.sql`. Therefore, it is recommended to pipe the contents of the SQL file to `psql` instead.

```
cat gather.sql | docker exec -i <container> psql -X -f - > out.tsv
```

* **Kubernetes**  environments have similar restrictions as those mentioned above. Therefore, a similar approach is recommended.

```
cat gather.sql | kubectl exec -i <PGpod> -- psql -X -f - > out.tsv
```

### Gathering data continuosly

In cases where the collection of data needs to be performed continously and repeatedly, `pg_gather` has a special lightweight mode for continuous data gathering. It is automatically enabled when it connects to the "template1" database.

!!! note
    For more information, see [Continuous Data collection](docs/continuous_collection.md).

## 2. Data Analysis

### 2.1 Importing collected data

You can import the collected data to a PostgreSQL instance, which creates the required schema objects in the `public` schema of the database.

!!! warning
    Avoid importing the data into critical environments/databases. A temporary PostgreSQL instance is preferable.

```
 psql -f gather_schema.sql -f out.tsv
```

The following is a deprecated usage of `sed`:

```
sed -e '/^Pager/d; /^Tuples/d; /^Output/d; /^SELECT pg_sleep/d; /^PREPARE/d; /^\s*$/d' out.tsv | psql -f gather_schema.sql -
```

### 2.2 Generating a report

You can generate an HTML format analysis report from the imported data by using the following command:

```
psql -X -f gather_report.sql > GatherReport.html
```

!!! note
     Generating the analysis report requires PostgreSQL version 13 or higher. You can view the report in any modern web browser.

## 2.3 Alternative Approach: Dockerized report generation

The steps for data analysis mentioned above require a PostgreSQL instance to import the data into. An alternative solution to this is to use the `generate_report.sh` script, which spins up a PostgreSQL Docker container and automates the entire process.

To use this script, place it in the same directory containing the `gather_schema.sql` and `gather_report.sql` files.

Once executed, the script:

1. Creates a PostgreSQL container.
2. Imports the output from `gather.sql` (i.e., `out.tsv`).
3. Generates an HTML report.

The script expects at least a single argument:

* the path to the `out.tsv` file.

It also accepts two optional positional arguments:

* Desired report name with path
* A flag to specify whether to keep the docker container. This flag permits the usage of the container and data for further analysis

**Example 1**: Import data and generate an HTML file

```
$ ./generate_report.sh /tmp/out.tsv
...
Container 61fbc6d15c626b484bdf70352e94bbdb821971de1e00c6de774ca5cd460e8db3 deleted
Finished generating report in /tmp/out.txt.html
```

**Example 2**: Import data, keep the container intact and generate the report in the specified location

```
$ ./generate_report.sh /tmp/out.tsv /tmp/custom-name.html y
...
Container df7b228a5a6a49586e5424e5fe7a2065d8be78e0ae3aa5cddd8658ee27f4790c left around
Finished generating report in /tmp/custom-name.html
```

## Advanced configurations

### Timezone

By default, the `pg_gather` report uses the same timezone of the server from which the data is collected, because it considers the `log_timezone` parameter for generating the report. This default timezone setting helps to compare the PostgreSQL log entries with the `pg_gather` report.
However, this may not be the right timezone for few users, especially when cloud hostings are used. The `pg_gather` allows the user to have a custom timezone by setting the environment variable `PG_GATHER_TIMEZONE` to override the default. For example,
```
export PG_GATHER_TIMEZONE='UTC'
```
Please use the timezone name or abbreviation available from `pg_timezone_names`
# Demo
## Data collection
[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/4EK7BoV6oOg/0.jpg)](https://youtu.be/4EK7BoV6oOg)
## Simple Report Generation (1min): 
[![Import data and Generate report using PG](https://img.youtube.com/vi/Y8gq1dwfzQU/0.jpg)](https://youtu.be/Y8gq1dwfzQU)
## Report generation using postgresql docker container made easy (3min): 
[![Import data and Generate report using PG docker container: made simple](https://img.youtube.com/vi/amPQRzz5D8Y/0.jpg)](https://youtu.be/amPQRzz5D8Y)