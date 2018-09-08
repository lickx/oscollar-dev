0008250: llMoveToTarget() in attachment plays 'landing' anim when on a prim floor
http://opensimulator.org/mantis/view.php?id=8250

When a scripted attachment calls llMoveToTarget() to move the wearer, the default 'landing' or 'flying' animation is sometimes played.

In the case of OsCollar, the bug is seen when taking a leashed person for a walk, and is specifically noticable when walking up and down ramps or staircases.

The patch adresses this by only playing those animations when not standing.