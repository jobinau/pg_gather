BEGIN {
  tpl = 0
}
{
  if (tpl == 0) {
    if ( /^<%.*%>/ ) {
      sub(/<%\s*/, "");
      sub(/\s*%>/, "");
      print
    } else if ( /^<%/ ) {
      tpl = 1;
      sub(/<%\s*/, "");
      print
    } else if ( /^\s*$/ ) {
      print
    } else {
      sub(/^/, "\\echo ");
      gsub(/'/, "''");
      print
    }
  } else {
    if ( /%>/ ) {
      tpl = 0;
      sub(/%>/, "");
      print
    } else {
      print
    }
  }
}
