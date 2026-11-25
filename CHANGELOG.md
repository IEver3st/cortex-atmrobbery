# Changelog

All notable changes to cortex-atmrobbery are listed here. Versions follow semantic versioning.

## 1.0.0 (2026-11-24)

First release.

### Added
- Rob any Cortex Banking ATM by hand in four stages on the machine itself: pry the service door with a crowbar, back out the cover plate screws, read and work the wiring, then pull the cassette and take the bundles.
- Every machine is wired at random from six roles (bolt coil, mains, two alarm loop wires, tamper line, dead). The meter reads each one, and the server alone knows which is which.
- Mistakes cost strikes: a slipped bar, a cammed screw, a dead short, mains into the wrong line. Too many and the machine locks down and rings.
- Dye packs, a tamper alarm with a 10-90 to police, a shock from the mains, and sparks from a bricked board.
- Other players see the whole robbery: the door and plate on the floor, the open bay, the cassette, dye smoke, the alarm.
- A robbed machine stays out of service in Cortex Banking until it is repaired.
- Own hand tool models (crowbar, driver, side cutters, probe, jumper clip and an ΩHMIGOD multimeter with a live LCD).
- `/atmrob` admin command, a Discord audit log through a server convar, and a work light toggle in the Cortex settings tab.
