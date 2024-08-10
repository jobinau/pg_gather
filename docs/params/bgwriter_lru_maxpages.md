# bgwriter_lru_maxpages

The bgwriter need to be sufficiently active and agreesive.
otherwise,major load of eviction (flushing the dirty pages) will be on the checkpointer and connection backends.