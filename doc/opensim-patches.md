Recommended patches for OpenSim

You wouldn't believe how often I got a "bug report" for what is actually a bug in OpenSim itself. Unfortunately the core devs don't see the urgency to address these problems in mainstream OpenSim, so you'll have to patch the OpenSim sourcecode yourself!

[Mantis 8366](http://opensimulator.org/mantis/view.php?id=8366)  
This fixes state being lost or even non-working scripts for any hypergrid visitors you receive at your sim. If you have been wondering why your collar (and other scripted attachments) lost any and all settings when hypergridding, this is it. The destination sim will have to apply these patches.

[Mantis 8366](http://opensimulator.org/mantis/view.php?id=8366) and [Mantis 9052](http://opensimulator.org/mantis/view.php?id=9052)  
After a TP to the hypergrid, your attachments won't be set to the active group tag for that grid, which is needed if you allow access from that group on the collar. The destination sim will have to apply these patches.

[Mantis 6311](http://opensimulator.org/mantis/view.php?id=6311) [Patch here](https://github.com/lickx/opensim-lickx/wiki/6311) 
This affects RLVa, when declining a folder given to your shared #RLV folder by a scripted object/trap. Accepting seems to be working now since OpenSim 0.9.2, decline will only work correctly after this patch is applied.

[Mantis 8250](http://opensimulator.org/mantis/view.php?id=8250)  
If your leashed sub has been bunny hopping or is stuck when walking up or down a hill, stairs, or other kind of slope, this patch fixes that leash weirdness.

Alternatively, run my [OpenSim fork](https://github.com/lickx/opensim-lickx) in which this all is fixed
