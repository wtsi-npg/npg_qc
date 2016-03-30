#####################################
Test scripts for SeqQC User Interface
#####################################

#. MQC-ing user can see MQC page

   *Scenario*
     Logged user request page of run which was taken (run in status 'qc in
     progress' or 'qc on hold') by same user for MQC. The user should have
     manual qc role.

   *Expected result*
     The page displays current MQC outcomes and MQC widgets when appropriate

#. Other user can see current MQC outcome

   *Scenario*
     Logged user requests page of run which was taken by someone else

   *Expected Result*
     The page displays with current MQC outcomes. Preliminary outcomes should
     differ from final outcomes.

#. Non-logged user can see current MQC outcomes

   *Scenario*
     Non-logged user request page of run which is being MQC-ed

   *Expected Result*
     The page displays with current MQC outcomes.  Preliminary outcomes should
     differ from final outcomes.

#. MQC-ing user can update the outcome from undecided to preliminary

   *Scenario*
     Logged user requests page of run which was taken for MQC by same user. The
     run has non-MQC-ed lanes. The page has MQC widgets for those lanes in
     'Undefined' outcome. The user can update the outcome of the MQC using the
     widgets.

   *Expected Result*
     User can update to preliminary outcome. The pressed button (tick, cross
     or empty light gray for 'Undecided') becomes dark. 'Save' icon appears for
     preliminary pass/fail. The relevant preliminary pass, fail or undecided
     record is created in the database.

#. MQC-ing user can update from preliminary outcome to undecided.

   *Scenario*
     Logged user requests page of run which was taken for MQC by same user. The
     run has lanes with preliminary outcomes. The user can update the outcome
     from a preliminary pass/fail to undecided.

   *Expected Result*
     User can update preliminary outcome back to undecided outcome. The pressed
     button becomes dark, the previous outcome button becomes light. The
     undecided outcome record is created in the database. 'Save' icon
     disappears.

#. MQC-ing user can update between preliminary pass/fail outcomes.

   *Scenario*
     Logged user requests page of run which was taken for MQC by same user. The
     run has lanes with preliminary outcomes. The user can update the outcome
     from preliminary pass to preliminary fail and vice versa.

   *Expected Result*
     User can update preliminary pass to preliminary fail and vice versa. The
     chosen outcome button becomes dark, the previousle selected becomes light,
     a new record is created in the database.'Save' icon persists.

#. MQC-ing user can update from preliminary to final outcomes.

   *Scenario*
     Logged user requests page of run which was taken for MQC by same user. The
     run has lanes with preliminary outcomes. The user can save the current
     preliminary outcome as final.

   *Expected Result*
     User can update preliminary pass/failed to final outcomes. Widgets are
     not available anymore for this lane. The lane changes background to show
     final outcome. The final outsome record is created in the database.

#. MQC-ing user can suspend MQC and come back to see latest outcomes

   *Scenario*
     Logged user requests page of run which was taken for MQC by same user. The
     run has lanes with undecided, preliminary and final pass/fail outcomes.
     The user can reload the page and the page shows the latests outcomes the
     user MQC-ed.

   *Expected Result*
     User always has the latest MQC outcomes everytime the page is loaded.

#. Run moves from 'qc in progress'/'qc on hold' to arch pending

   *Scenario*
     Logged user request page of run which was taken for MQC by same user. The
     run has non-MQC-ed lanes. The page has MQC widgets for those lanes with
     undefined, undecided or preliminary outcomes. The user can MQC all lanes
     and save them as final.

   *Expected Result*
     The run moves to arch pending when all lanes have been assigned a final
     MQC outcome. Correct transactional behaviour on npg_tracking database is
     prerequisite, therefore, might not work occasionally.

#. Run last MQC outcome is visible after MQC is complete

   *Scenario*
     Logged user can see latest MQC outcomes for lane in run which moved beyond
     qc in progress.

   *Expected Result*
     User can see latest MQC outcomes for lane in run which moved beyond qc in
     progress.

#. Run last MQC outcome is visible after MQC is complete for non-logged user

   *Scenario*
     User can see latest MQC outcomes for lane in run which moved beyond 'qc in
     progress'/'qc on hold'.

   *Expected Result*
     User can see latest MQC outcomes for lane in run which moved beyond qc in
     progress.

#. Lane can only be saved as final pass when no corresponding plexes are
   undecided

   *Scenario*
     MQC-ing user tries to save a lane as final pass when there are plexes
     without a preliminary pass/fail.

   *Expected Result*
     Page displays error mentioning number of plexes with preliminary outcome
     does not match the total number of plexes expected.

#. Lane can only be saved as final fail when all corresponding plexes have been
   marked as undecided

   *Scenario*
     MQC-ing user tries to save a lane as final fail when there are plexes with
     preliminary pass/fail.

   *Expected Result*
     Page displays error message mentioning all plexes need to be set as pass or
     fail.

#. MQC-ing user can see a link for manual QC help page

   *Scenario*
     MQC-ing user requests page for run taken for MQC by same user.

   *Expected Result*
     The page displays a link in the upper right corner menu which points to
     the help page for MQC.
