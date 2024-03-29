Traveller Astromapper
==========================

The **Traveller Astromapper** creates random Traveller star maps intended for YOTU (Your Own Traveller Universe).

The maps are generated using an inspired amalgam of [Mongoose](http://www.mongoosepublishing.com/rpgs/traveller/core-rulebooks-accessories.html) and [Classic Traveller](http://www.farfuture.net/) rules, with some [Gurps Space](http://www.sjgames.com/gurps/books/space/) 4e and 3e.

Mongoose rules are used when generating the World characteristics. Classic Traveller is used when fleshing out star system details such as stars, non-world orbits, presence of companion stars. Gurps is used to flesh out star characteristics and the impact of a companion star on the primary's orbits.

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

Copyright
=========

Copyright 2012--13, Benjamin C. Wilson. All Rights Reserved.

You may not use this work for commercial purposes. You may not alter, transform or build upon this work. Any of the above conditions can be waived if you get permission from the copyright holder. Where the work or any of its elements is in the public domain under applicable law, that status is in no way affected by the license. For any reuse or distribution, you must make clear to others the license terms of this work. In no way are any of the following rights affected by the license:

* Your fair dealing or fair use rights, or other applicable copyright exceptions and limitations;
* The author's moral rights;
* Rights other persons may have either in the work itself or in how the work is used, such as publicity or privacy rights.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Product names, logos, brands, and other trademarks featured or referred to in  software are the property of their respective trademark holders. Usage of those marks does not convey sponsorship or endorsement of this generator.

Credits
=======

SVG Output uses some algorithms from [phreeow.net Perl mapping software](http://www.phreeow.net/wiki/tiki-index.php?page=Subsector+mapping+and+generating+software) with drawing hexes in the Classic Traveller way.

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