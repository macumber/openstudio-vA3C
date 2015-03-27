# openstudio-vA3C

Exporter of OpenStudio Model to [vA3C](http://va3c.github.io/) JSON format.  This reporting measure exports an OpenStudio model to the [vA3C](http://va3c.github.io/) JSON format.  Additional user data is added to all surfaces in the export.  The JSON file is configured into an html file and rendered using Three.js.  

A huge thanks goes out to [Theo Armour](https://github.com/theo-armour) and the [vA3C team](http://va3c.github.io/) for helping figure out how to do all this stuff.

Todo:
- [x] Basic 3D rendering
- [ ] Support multiple render modes (boundary condition, construction, thermal zone, outward normal)
- [ ] Ability to render all stories or subset of stories
- [ ] Section cuts
- [ ] Render by data
