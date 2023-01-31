#################################################################
#  AWK script by Nickolay Ihalainen
#  Generate the SQL script (report.sql) for final analysis report 
#  Using HTML Template by replacing markers
#################################################################  

function psql_echo_escape() {
  in_double_quotes = 0
  split($0, chars, "")
  for (i=1; i <= length($0); i++) {
    ch = chars[i]
    if (ch == "\"" && in_double_quotes == 0) {
      in_double_quotes = 1
      printf("%s", "\"")
    } else if (ch == "\"" && in_double_quotes == 1) {
      in_double_quotes = 0
      printf("%s", "\"")
    } else if (ch == "'" && in_double_quotes == 0) {
      printf("%s", "''")
    } else {
      printf("%s", chars[i])
    }
  }
}

BEGIN {
  tpl = 0
}
{
  if (tpl == 0) {
    if ( /^<%.*%>/ ) {       ## Single line SQL statement/psql command
      sub(/<%\s*/, "");
      sub(/\s*%>/, "");
      print
    } else if ( /^<%/ ) {    ## Multi line SQL statement starting
      tpl = 1;
      sub(/<%\s*/, "");
      print
    } else if ( /^\s*$/ ) {  ## Empty lines for readability can be removed
      #print
    } else if ( /\w*\/\// ) {  ## Comments with double slash can be removed

    } else {                 ## Remaining lines (HTML tags) echo as it is
      sub(/^/, "\\echo ");
      psql_echo_escape()     ## Replace single quotes outside double quotes with escaped value
      printf("\n")
    }
  } else {                   ## Following lines of Multi line SQL statement 
    if ( /%>/ ) {            ## Last line of the Multi line SQL statement
      tpl = 0;
      sub(/%>/, "");
      print
    } else {                 ## All lines in between starting and last line of multi line statement
      print
    }
  }
}
