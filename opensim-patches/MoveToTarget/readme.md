0008250: llMoveToTarget() in attachment plays 'landing' anim when on a prim floor
http://opensimulator.org/mantis/view.php?id=8250


With OsCollar, or any OpenCollar for that matter, when someone is leashed then
repeatedly the 'landing' animation is played and sometimes 'flying'. This patch
addresses this issue.


For OpenSim 0.8:

cd opensim-0.8.2.1-source
patch -p1 --dry-run -i ~/Downloads/fixmovetotarget8.patch
no errors with dry-run? then:
patch -p1 -i ~/Downloads/fixmovetotarget8.patch


For OpenSim 0.9 or git master:

cd opensim-0.9.1-source
patch -p1 --dry-run -i ~/Downloads/fixmovetotarget9.diff
no errors with dry-run? then:
patch -p1 -i ~/Downloads/fixmovetotarget9.diff

