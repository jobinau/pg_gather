#################################################################
#  AWK script by Nickolay Ihalainen
#  Generate the SQL script (report.sql) for final analysis report 
#  Using HTML Template by replacing markers
#################################################################  

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
    } else if ( /^\s*$/ ) {  ## Empty lines
      print
    } else {                 ## Remaining lines (HTML tags) echo as it is
      sub(/^/, "\\echo ");
      gsub(/'/, "''");
      print
    }
  } else {                  ## Following lines of Multi line SQL statement 
    if ( /%>/ ) {           ## Last line of the Multi line SQL statement
      tpl = 0;
      sub(/%>/, "");
      print
    } else {                ## All lines in between starting and last line of multi line statement
      print
    }
  }
}
