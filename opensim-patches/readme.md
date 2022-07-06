This folder used to contain patches for OpenSim

You wouldn't believe how often I got a "bug report" for what is actually a bug in OpenSim itself. Unfortunately the core devs don't see the urgency to integrate my patches in mainstream OpenSim, so you'll have to patch the OpenSim sourcecode yourself!

So I now link you to the respective Mantis'es, where you can get the attached patches affecting collar and RLV roleplay:

[Mantis 8366](http://opensimulator.org/mantis/view.php?id=8366)  
This fixes state being lost or even non-working scripts after teleporting to a hypergrid destination. If you have been wondering why your collar (and other scripted attachments) lost any and all settings, this is it.

[Mantis 6311](http://opensimulator.org/mantis/view.php?id=6311) [Patch here](https://github.com/lickx/opensim-lickx/wiki/6311) 
This affects RLVa, when declining a folder given to your shared #RLV folder by a scripted object/trap. Accepting seems to be working now, decline doesn't in OS master.

[Mantis 8250](http://opensimulator.org/mantis/view.php?id=8250)  
If your leashed sub has been bunny hopping or is stuck when walking up or down a hill, stairs, or other kind of slope, this patch fixes that leash weirdness.
