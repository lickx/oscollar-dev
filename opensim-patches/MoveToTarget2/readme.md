llMoveToTarget should not execute in attachment when avi is seated #6
https://github.com/lickx/opensim/issues/6

When a scripted attachment calls llMoveToTarget() while the wearer is seated, the simulator will continuously throw exception errors. This leads very quickly to a slowdown and possibly a sim crash.

In the case of OsCollar this happens when force-sitting a leashed person.

The patch adresses this issue by silently ignoring llMoveToTarget() if the calling script is in a seated avatar.