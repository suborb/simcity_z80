# Sim City Z80

This is a work-in-progress disassembly of the ZX Spectrum version of Sim City.

## Background

This disassembly was started back in 2000 with the aim of porting the whole
game to the z88.

## Analysis

As can be seen with the NES version (and presumably others as well), the
game consists of two processes:

* A UI process, responsible for handling user input and rendering the display
* A simulation process

This separation should make it possible to retarget the engine to run on any
Z80 based computer.


