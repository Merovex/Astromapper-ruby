Traveller Astromapper
==========================

The **Traveller Astromapper** creates random Traveller star maps intended for YOTU (Your Own Traveller Universe).

The maps are generated using an inspired amalgam of [Traveller5](http://www.farfuture.net/) and [Classic Traveller](http://www.farfuture.net/) rules, with some [Gurps Space](http://www.sjgames.com/gurps/books/space/) 4e and 3e.

Traveller5 WorldGen (the StSAHPGL-T tables) is used when generating the World characteristics (the UWP). Classic Traveller is used when fleshing out star system details such as stars, non-world orbits, presence of companion stars. Gurps is used to flesh out star characteristics and the impact of a companion star on the primary's orbits.

* Sector: 40x32 hex grid
* Tract:  8x10 hex grid (Traveller Subsector)
* Volume: 1-hex
* World: primary inhabited planet.
* Orbit: A slot around primary star, may include companion stars, planets, belts or nothing.

Installation
============

This software relies upon Ruby 1.9.2+.

To convert from SVG to JPG, PNG, GIF you will need to install Imagemagick with -rsvg flag (later feature).

How to Use Traveller Astromapper
======================

To create a new Traveller Astromapper project, execute the following on the command line:

```
astromapper new yotu_sector
```

The command creates the following directory structure:

```
yotu_sector
├── _astromapper.yml
├── output
└── templates
    └── names.yml
```

ASCII Output
------------

The block below shows Traveller Astromapper's ASCII output. The top row is the key system aspects: Volume ID, World UWP, Temperature, Presence of Bases & Gas Giants, Trade Codes, Stars, Primary Star's Orbits, Name. The rows that follow elaborate the primary star's orbits. Rows with two dashes are the Primary's orbits, orbit type, UWP, and orbit distance (usable for travel and year length). Other rows with the '/' are that orbit's satellites. When the UWP is dots, that orbit is empty.

```
1201 E949556-5 T ..G.. .. Lt,NI                     F0IV/DB           R..WGG..S         Secundus
  --  1.    R // X600000-0 //  0.4 au
                            /    7 rad. X420000
                            /    9 rad. X620000
  --  2.    . // .......-. //  0.7 au
  --  3.    . // .......-. //  1.4 au
  --  4. *  W // E949556-5 //  2.8 au
  --  5.    G // Large GG  //  5.6 au
  --  6.    G // Large GG  // 11.2 au
                            /    1 rad. XR00000
                            /    6 rad. X402000
                            /    7 rad. X405000
                            /    9 rad. X100000
                            /   10 rad. X302000
  --  7.    . // .......-. // 22.4 au
  --  8.    . // .......-. // 44.8 au
  --  9. -  S // DB        // 89.6 au
```

To generate a (mostly) random Traveller sector in the ASCII format, execute the following on the command line:

```
astromapper generate
```

SVG Output
----------

Traveller Astromapper converts the ASCII output as described above to create an SVG file describing the key aspects of a volume. This includes the Star type, Starport, Name and the presence of bases (Navy, Scout, etc.) and Gas Giants.

To convert that ASCII into an SVG image, execut the following:

```
astrographer svg
```

License
=======

The Astromapper software is released under the **MIT License**. The game rules it
implements (Traveller, GURPS) are used under their respective fair-use policies. See
[LICENSE.md](../LICENSE.md) for the full text — MIT license, the Far Future Enterprises
Traveller Fair Use Policy, the Steve Jackson Games / GURPS notice, and credits.

Known bugs
===========
* If the dice pool is too small, the generated output will repeat.

Troubleshooting
===============

Changelog
=========

Version 0.1 (1 March 2012) 
--------------------------
* Initially written
* Generate Sector Map
* Convert to SVG

Version 1.0 (7 April 2013)
--------------------------
* Re-implemented as Ruby Gem

* A News sections might also be include to lists project updates for users.