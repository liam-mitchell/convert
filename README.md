# convert++ - an N1.4 to N++ userlevel converter

***convert++*** is a little tool to convert N1.4 userlevel data into the binary format used by N++, so your old 1.4 maps can see the light of day once again in the N++ user levels section.

There are a few caveats to this conversion, since the new format doesn't quite support all the options the old one did. When any of these are encountered, a warning will be displayed along with the level name so you can manually inspect it and determine whether/how to resolve the problem.

- Some drone pathing behaviours ('alternating' and 'quasi-random') from 1.4 have been removed from N++. Also removed is the ability to 'NaN' a drone path, preventing any motion at all. These drones are defaulted to the 'dumb CCW' direction, but should almost definitely be checked and reworked somehow.
- Edited launchpads no longer work, since the power of a launchpad is set in the game code rather than the level data. So no more teleporters :(
- Z-snapped coordinates are more precise in 1.4, since it uses a finer grid. These are rounded to the nearest tile which is *usually* okay but this warning should probably still be checked out.