[lickx] llMoveToTarget should not execute in attachment when avi is seated #6
https://github.com/lickx/opensim/issues/6

When a leashed sub is seated, the sim will continuously throw exception errors because the sim tries to MoveToTarget the subject wearing the attachment (collar in this case) in which the call to MoveToTarget is made. This leads very quickly to a slowdown and possibly a sim crash.


General patch instructions:

cd opensim-source  
patch -p1 --dry-run -i ~/Downloads/fix.diff  

no errors with dry-run? then:  
patch -p1 -i ~/Downloads/fix.diff  

