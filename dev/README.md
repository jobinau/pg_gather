# Documentation for Developers

## How to build
The project uses tempate for writing report generation code. please refer the file `gather_report.tpl.html`
The AWK script `apply_template.awk` is used for generating the report.sql (or ../gather_report.sql)
```
cat gather_report.tpl.html | awk -f apply_template.awk  > report.sql; psql -X -f report.sql > out.html  
```
## SQL Statement Documentation
Please refer [SQL documentation](SQLstatement.md) on SQL statement used in this project.