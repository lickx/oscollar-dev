### Welcome to OsCollar

OsCollar is a set of gadgets for submission roleplay for use in the OpenSim metaverse

Grid and sim owners might want to read [opensim patches](doc/opensim-patches.md)

For help and chatter, join us on [Matrix](https://matrix.to/#/#oscollar:matrix.org)


#### Finding your way around this repo
```
./oscollar/

    > doc: Useful information and documentation

    > res: Resource of creative content.

        > anims: Motions and Animations as .bvh and .avm binaries.
        > models: 3D Models as .dae and .blend binaries.
        > sounds: Sounds as .wav and .aup binaries.
        > textures: Images as .png and .xcf binaries.

    > src: Source code of the OsCollar role play device.

        > ao: The source code for the animation overrider.
        > apps: Fun features you can add to your device
        > device: Everything you need for a full featured device
        > extensions: Enhanced features that can be added to a device
        > installer: The source code for the updater aka patch
        > remote: The source code for the remote control HUD.
        > spares: Spares and snippets for research and development.

    > web: Files for the updater check within the Help/About menu
```

#### Requirements

Simulator: OpenSim 0.9.3.1 or newer

Teleporting to a sim running older versions of OpenSim may result in loss of settings (linkset data) and loss of functionality (non-running scripts)  
Teleporting to a hypergrid sim may result in scripts to stop running and/or reset, unless the destination sim is patched  

General advice is to only use this on your home grid running the recommended OpenSim version.
