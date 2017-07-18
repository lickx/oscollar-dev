### Welcome to OsCollar Six™

OsCollar Six is a fork of OpenCollar Six with increased compatibility for OpenSim virtual worlds. The OpenCollar repository can be found [here](https://github.com/VirtualDisgrace/opencollar)

OpenCollar Six is a set of LSL scripts and other creative content, such as animations, sounds, textures, graphics and 3D models, which can be used to create role play devices in the form of scripted accessory and/or so-called HUDs.

Punk, goth and fetish collars would be the most popular of those and OpenCollar eventually became everyone's script set of choice to create items that are used for creative role play amongst adults in Second Life®.

#### Finding your way around this repo

At the moment this repository is separated into resources, source code and web queries. The directory names are self-explanatory and each has a readme attached that tells about specific details. Resource subdirectories inform which file formats we work with and point to other free software that can be used to create such content.

```
./opencollar/

    > res: Resource of creative content.

        > anims: Motions and Animations as .bvh and .avm binaries.
        > models: 3D Models as .dae and .blend binaries.
        > sounds: Sounds as .wav and .aup binaries.
        > textures: Images as .png and .xcf binaries.

    > src: Source code of the OpenCollar Six role play device.

        > ao: The source code for the animation overrider.
        > collar: The source code for the collar device.
        > installer: The source code for the package manager.
        > remote: The source code for the remote control HUD.
        > spares: Spares and snippets for research and development.

    > web: Web queries.
```

#### License Terms and Addendum

OpenCollar Six source code and creative resource are covered by free software, free culture and permissive open-source software licenses. Each script is its own program and compiles individually.

* Most LSL scripts are licensed as and must remain under the [GNU General Public License, version 2](http://www.gnu.org/licenses/gpl-2.0).

* The LSL scripts ``oc_root``, ``oc_lock``, ``oc_stealth`` and ``oc_update`` have the [Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0) license.

* Creative content is licensed as and must remain under the [Creative Commons Attribution-ShareAlike 4.0 International Public License](https://creativecommons.org/licenses/by-sa/4.0/).

* Everything else that is shared within the metaverse and where no explicit license was applied is covered by the [License Terms for the OpenCollar Six Role Play Device](https://raw.githubusercontent.com/VirtualDisgrace/opencollar/master/LICENSE).

**NOTE:** Please make sure that you have read and understood the full legal text of each license if your interest in OpenCollar Six goes beyond personal use (i.e. commercial redistribution). For human-readable summaries of various licenses, check out [tl;drLegal](https://tldrlegal.com/)

**A few words on authorship, years and copyright:**

OpenCollar source code has been composed by many different authors and while not all authors composed something in every year since 2008, we chose to state copyright as year spans (i.e. Copyright (c) 2008 - 2017) in our copyright notice.

We chose to do that in order to save space in a already cramped screen environment with in-world LSL editors. Nevertheless, we tried our best to make all authors appear in order of appearance if read from left to right. <3

#### OpenSim Porting Information

We target and test for OpenSim 0.8 (stable) and OpenSim 0.9 (unstable, master)

Branches: 
 
master - development branch for OpenSim 0.9+  
oscollar6 - stable port of OpenCollar Six for OpenSim 0.8+  
oscollar3 - stable port of OpenCollar 3.99x for OpenSim 0.8+  
 
There are some differences between the v3 and Six collars, for instance Six is much more optimized thanks to certain scripts being in seperate links (which can be optionally invisible, but you do need them seperate).

If you are looking to directly convert or upgrade existing v3 collars for OpenSim, you can use the oscollar3 branch which should be 100% compatible with the last v3 version in Second Life. We haven't made a transmuter tool yet to convert a v3 collar to Six.

A ready made standard OpenCollar for both branches can be be aquired at the OsGrid Sim ['Kinky Hub'](http://opensimworld.com/hop/78323-Kinky-Hub). Creators can use this standard collar as a technical reference for making new products.
