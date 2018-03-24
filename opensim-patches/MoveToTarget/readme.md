0008250: llMoveToTarget() in attachment plays 'landing' anim when on a prim floor
http://opensimulator.org/mantis/view.php?id=8250


With OsCollar, or any OpenCollar for that matter, when someone is leashed then
repeatedly the 'landing' animation is played and sometimes 'flying'. This patch
addresses this issue.


General patch instructions:

cd opensim-source  
patch -p1 --dry-run -i ~/Downloads/fix.diff  

no errors with dry-run? then:  
patch -p1 -i ~/Downloads/fix.diff  

