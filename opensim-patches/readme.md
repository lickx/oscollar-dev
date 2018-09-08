This folder contains any patches that have not been merged into mainline OpenSim (yet)

General patch instructions:

cd opensim-source  
patch -p1 --dry-run -i ~/Downloads/fix.diff  

no errors with dry-run? then:  
patch -p1 -i ~/Downloads/fix.diff  
