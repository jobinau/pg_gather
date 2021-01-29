# Files for developers
Files in this directory are for developers of this pg_gather using  a html tempalte and awk script

```
cat gather_report.tpl.html | awk -f apply_template.awk  > report.sql; psql -X -f report.sql > out.html

```
