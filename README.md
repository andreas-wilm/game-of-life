# Conway's Game of life in Nim with SDL2

## Why?

Because I needed something to tinker with. This started as a one day experiment for brushing up my Nim skills and got a bit out of hand. The code is not optimized in any way and really just my playground.

## Features:

- With colors (inspired by [Jim Blackler's version](https://jimblackler.net/blog/?p=384)):
  - At startup the cells are assigned colors randomly
  - Newly-created cells take the most common color of neighbouring cells
  - When cells die, they leave a shaded version of their original color
- Borderless (optional)
- REL import

## Other Nim implementations

There are plenty of other Game of life implementations in Nim on Github for example. Only after I started this project, I found another [Nim implementation using SDL (actually Nimgame2)](https://github.com/KieranP/Game-Of-Life-Implementations) by [andrew644](https://github.com/andrew644) and the code looks a lot nicer. Unfortunately I couldn't get it to work under WSL2, because SDL can't find an audio device...

## Build

You will need [Nim](https://nim-lang.org/install_unix.html) as well as [SDL2](https://wiki.libsdl.org/Installation) installed.

Run `nimble build` (which also installs required Nim packages).

The resulting binary is called `gol`.

Run `./gol -h` to see command-line arguments.

For importing RLE patterns (e.g. downloaded from the [LifeWiki](https://www.conwaylife.com/)), it's a good idea to add some padding, e.g. `./gol -f patterns/p5760unitlifecell.rle -c 1 -p 100`

If you are under WSL2 and this segfaults early, please set the `DISPLAY` variable.

Under Ubuntu/WSL2 I first had to link libSDL2-2.0.so.0 so that Nimble would find it:
`ln -s /usr/lib/x86_64-linux-gnu/libSDL2-2.0.so.0 libSDL2.so`

## TODO

- Support "unlimited" universe with zoom
- Speed improvements:
  - Use sparse matrix
  - Use of fillRect instead of drawPoint (for `c>1`)?

# Screenshots

## From a random start position

![Random Start](./screenshots/random.png "Random start position")

## [Methusaleh: Wilma](https://www.conwaylife.com/wiki/Wilma)

After 1043 generations with a few escaping [gliders](https://www.conwaylife.com/wiki/Glider)

![Wilma](./screenshots/wilma-1043.png "Wilma 1043th generation")

## [Metacell: p5760 unit Life cell](https://conwaylife.com/wiki/P5760_unit_Life_cell)

After 397 generations.

![p5760](./screenshots/p5760-gen397.png "p5760 unit Life cell 397th generation")
