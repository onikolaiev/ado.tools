enum ProjectState {
    All            # All projects regardless of state except Deleted.
    CreatePending  # Project has been queued for creation, but the process has not yet started.
    Deleted        # Project has been deleted.
    Deleting       # Project is in the process of being deleted.
    New            # Project is in the process of being created.
    Unchanged      # Project has not been changed.
    WellFormed     # Project is completely created and ready to use.
}