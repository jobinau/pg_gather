# FILLFACTOR RECOMMENDATION

Max 20% of space is considered for HOT updates (Redution in fill factor)
So fillfactor : 100 - 20% max
What is the proportion of new tuples coming due to UPDATES. reduce the above mentioned 20% if UPDATES are less.
So fillfactor : 100 - 20%*UPDATES/(UPDATES+INSERTS)
Even if updates are high, lot of hot updates are already happening, the additional the fraction of free space can be reduced according to the ratio of  HOTUPDATE/UPDATES
  20%*UPDATES/(UPDATES+INSERTS) * HOTUPDATE/UPDATE
So fillfactor : 100 - 20%*UPDATES/(UPDATES+INSERTS) + 20%*UPDATES/(UPDATES+INSERTS) * HOTUPDATE/UPDATE