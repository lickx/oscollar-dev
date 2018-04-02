### Welcome to OsCollar

OsCollar is a fork of OpenCollar, specifically optimized for OpenSim virtual worlds.

OsCollar is a set of LSL scripts and other creative content, such as animations, sounds, textures, graphics and 3D models, which can be used to create role play devices in the form of scripted accessory and/or so-called HUDs.

Punk, goth and fetish collars would be the most popular of those and OpenCollar eventually became everyone's script set of choice to create items that are used for creative role play amongst adults in Second Life®.

#### Finding your way around this repo

At the moment this repository is separated into resources, source code and web queries. The directory names are self-explanatory and each has a readme attached that tells about specific details. Resource subdirectories inform which file formats we work with and point to other free software that can be used to create such content.

```
./oscollar/

    > opensim-patches: Recommended patches for the OpenSim sources

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
```

#### Licensing Information

OpenCollar source code and creative resource are covered by free software, free culture and permissive open-source software licenses. Each script is its own program and compiles individually.

* Most LSL scripts are licensed as and must remain under the [GNU General Public License, version 2](http://www.gnu.org/licenses/gpl-2.0).

* Some scripts, most notably ``oc_root`` have the [Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0) license.

* Some creative content is licensed as and must remain under the [Creative Commons Attribution-ShareAlike 4.0 International Public License](https://creativecommons.org/licenses/by-sa/4.0/).

* Everything else that is shared within the metaverse and where no explicit license was applied is covered by the [License Terms for the OpenCollar Role Play Device](https://raw.githubusercontent.com/lickx/oscollar/master/LICENSE).

**NOTE:** Please make sure that you have read and understood the full legal text of each license if your interest in OpenCollar goes beyond personal use (i.e. commercial redistribution). For human-readable summaries of various licenses, check out [tl;drLegal](https://tldrlegal.com/)

**A few words on authorship, years and copyright:**

OpenCollar source code has been composed by many different authors and while not all authors composed something in every year since 2008, we chose to state copyright as year spans (i.e. Copyright (c) 2008 - 2017) in our copyright notice.

We chose to do that in order to save space in a already cramped screen environment with in-world LSL editors. Nevertheless, we tried our best to make all authors appear in order of appearance if read from left to right. <3

#### OpenSim Porting Information

Since many grids are still on OpenSim 0.8.x that is our base target

Branches: 
 
master - development branch  
oscollar6 - stable release  
 
A reference collar is available in the region 'Kinky Hub' in [OsGrid](https://www.osgrid.org). The hypergrid address to get there is 'hg.osgrid.org:80:Kinky Hub'. With your avatar from any open grid, copy/paste the address in the World Map, then press Search followed by Teleport.

UUIDs referenced by code and notecards refer to assets on the OsGrid.org asset server.
