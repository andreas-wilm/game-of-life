# Conway's Game of life in Nim with SDL2

Features:
- With colors (inspired by [Jim Blackler's version](https://jimblackler.net/blog/?p=384))
- Borderless (optional)


## Why?

Because I needed something to tinker with.

## Other Nim implementations

There are plenty of other Game of life implementations in Nim e.g. on Github. Only after I started tinkering, I found another [Nim implementation using SDL/Nimgame2](https://github.com/KieranP/Game-Of-Life-Implementations) by [andrew644](https://github.com/andrew644), which is a lot nicer. Unfortunately I couldn't get it to work under WSL2,
because it can't find an audio device...


## Build

You will [Nim](https://nim-lang.org/install_unix.html) as well as [SDL2](https://wiki.libsdl.org/Installation) installed.

Then run `nimble build` (which also installs required Nim packages).

The resulting binary is called `gol`. Run `./gol -h` to see command-line arguments.

## TODO

- support RLE import
- leave background color
