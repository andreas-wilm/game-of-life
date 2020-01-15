## Yet another Game of Life implementation. This one is based on Nim and SDL.
#
# Author: Andreas Wilm
# License: MIT, see LICENSE


# standard library
import os
import random
import sequtils
import strformat
import strutils
import colors
import tables
import cligen
import times
# third party
import sdl2
# project
import rle


type SDLColorTuple = (uint8, uint8, uint8, uint8)

type World = object
  height: int
  width: int
  cells: seq[seq[bool]]# true == alive
  colors: seq[seq[SDLColorTuple]]
  borderless: bool
  changedCells: seq[(int, int)]

# FIXME color handling should be natively SDL
const COLORS = @[colRed, colYellow, colBlue, colGreen, colOrange, colPurple]

proc nimToSDLColorTuple(c: colors.Color): SdlColorTuple
let SDL_COLORS = COLORS.mapIt(nimToSDLColorTuple(it))
let SDL_COLORS_SHADED = COLORS.mapIt(nimToSDLColorTuple(intensity(it, 0.2)))

let SDL_COLOR_DEAD = nimToSDLColorTuple(colBlack)


randomize()


proc nimToSDLColorTuple(c: colors.Color): SDLColorTuple =
  let a = uint8(255)
  let rgb = extractRGB(c)
  let r = uint8(rgb[0])
  let g = uint8(rgb[1])
  let b = uint8(rgb[2])
  return (r, g, b, a)


proc numCellsAlive(w: World): int =
  # while intuitive, there surely must be a cleverer way.
  # maybe map(), but how for 2d and with custom types?
  for r in 0..<w.height:
    for c in 0..<w.width:
      if w.cells[r][c]:
        inc result


proc populate(world: var World, density = 0.25) =
  ## populates ``world`` with randomly places cells.
  ## chance of a living cell equal ``density``
  for row in 0..<world.height:
    for col in 0..<world.width:
      let isAlive = bool(rand(1.0) < density)
      var c = SDL_COLOR_DEAD
      if isAlive:
        c = sample(SDL_COLORS)
      world.cells[row][col] = isAlive
      world.colors[row][col] = c


proc createNewWorld(height, width: int, borderless = false): World =
  ## creates a new world, which is empty. call populate() or
  ## set status for all cells afterwards.
  result.height = height
  result.width = width
  result.cells = newSeqWith(height, newSeq[bool](width))
  result.colors = newSeqWith(height, newSeq[SDLColorTuple](width))
  result.borderless = borderless
  for row in 0..<height:
    for col in 0..<width:
      result.changedCells.add((row, col))


proc getLiveNeighbourCoords(w: World, row: int, col: int): seq[(int, int)] =
  ## returns coordinates (int tuple) for all neighbouring cells that are alive
  let neighbourOffsets = [[-1, 1],  [0, 1],  [1, 1],
                          [-1, 0],           [1, 0],
                          [-1, -1], [0, -1], [1, -1]]

  for (roff, coff) in neighbourOffsets:
    var nrow, ncol: int# neighbour coordinates
    var isAlive: bool
    nrow = row + roff
    ncol = col + coff

    # the rest is dealing with border cases
    if w.borderless:
      if nrow == -1:
        nrow = w.height - 1
      elif nrow == w.height:
        nrow = 0
      if ncol == -1:
        ncol = w.width - 1
      elif ncol == w.width:
        ncol = 0
      isAlive = w.cells[nrow][ncol]
    else:
      # this has weird side effects, for example
      # a glider leaving the screen leaves behind a still square of 4
      if nrow == -1 or nrow == w.height:
        isAlive = false
      elif ncol == -1 or ncol == w.width:
        isAlive = false
      else:
        isAlive = w.cells[nrow][ncol]

    if isAlive:
      result.add((nrow, ncol))


proc mostCommonNeighbourColor(world: World, row: int, col: int): SDLColorTuple =
  ## returns color most common in neighbouring cells that are alive.
  ## choses color randomly from the list on ties.
  var liveColors = initCountTable[SDLColorTuple]()
  for (row, col) in getLiveNeighbourCoords(world, row, col):
    liveColors.inc(world.colors[row][col])
  result = liveColors.largest[0]


proc cellAliveInNextGen(world: World, row: int, col: int): bool =
  ## determine whether cell will live in next generation
  let currentlyAlive = world.cells[row][col]
  let numLiveNeighbours = len(getLiveNeighbourCoords(world, row, col))
  if currentlyAlive == true:
    # 0..1:# lonely
    if numLiveNeighbours in 2..3:# just right
      return true
    # 4..8:# overcrowded
  else:
    if numLiveNeighbours == 3:# give birth
      return true
    # else:# barren
  return false


proc updateWindow(renderer: RendererPtr, world: World, cellSize: int) =
  ## draws update of changes cells
  #echo fmt"DEBUG updating {len(world.changedCells)} changed cells"
  for (row, col) in world.changedCells:
      renderer.setDrawColor(world.colors[row][col])
      # draw a square with dimension cellSize
      for i in 1..cellSize:
        for j in 1..cellSize:
          renderer.drawPoint(cint(col * cellSize + i),
                             cint(row * cellSize + j))
      # or use SDL: might be faster
      # don't use in its current form: this seems to draw an oval at higher
      # cellsizes and coordinates are all wrong.
      #var r = rect(cint(col), cint(row), cint(cellSize), cint(cellSize))
      #renderer.fillRect(r)
  renderer.present


proc evolve(world: var World, nextWorld: var World) =
  ## evolve the current world and saves results in nextWorld
  nextWorld.changedCells = @[]
  for row in 0..<world.height:
    for col in 0..<world.width:
      let isAlive = world.cells[row][col]
      let willLive = cellAliveInNextGen(world, row, col)
      var c = world.colors[row][col]# default to keep color

      if willLive xor isAlive:
        nextWorld.changedCells.add((row, col))

      if willLive and not isAlive:
        # just born? apply most common color
        c = mostCommonNeighbourColor(world, row, col)
      elif not willLive and isAlive:
        # just deceased? shade
        # FIXME this is stupid
        let idx = find(SDL_COLORS, c)
        c = SDL_COLORS_SHADED[idx]

      nextWorld.cells[row][col] = willLive
      nextWorld.colors[row][col] = c
  world = nextWorld


proc gol(width = 640, height = 480, cellSize = 4,
         withBorder: bool = false, sleepSecs = 0.0, density = 0.15,
         maxGenerations = -1, rleFile = "", rlePadding = 0): int =
  ## main function. meaning of arguments is described below in
  ## cligen interface.
  var winWidth = width
  var winHeight = height
  var borderless = not withBorder
  var cellsRLE: seq[seq[bool]]

  if len(rleFile)>0:
    echo "Loading world"
    var info: Info
    (cellsRLE, info) = parseRLEFile(rleFile, rlePadding)
    if info.rule != "B3/S23":
      quit("Only supporting rule B3/S23 at the moment")
    assert len(cellsRLE)>0
    winHeight = len(cellsRLE) * cellSize
    winWidth = len(cellsRLE[0]) * cellSize
    borderless = false
    # density unused in this casr

  let worldWidth = winWidth div cellSize
  let worldHeight = winHeight div cellSize
  var world = createNewWorld(worldHeight, worldWidth, borderless)
  var nextWorld = deepCopy(world)

  echo "Populating world"
  if len(cellsRLE) > 0:
    #echo fmt"DEBUG: cellsRLE = {len(cellsRLE)}x{len(cellsRLE[0])} vs {world.height}x{world.width}"
    world.cells = cellsRLE
    for row in 0..<world.height:
      for col in 0..<world.width:
        if world.cells[row][col]:
          world.colors[row][col] = sample(SDL_COLORS)
  else:
    if cellSize*3 > min(winWidth, winHeight):
      quit("Cell size too big for screen")
    world.populate(density)

  echo "Setting up window"
  var window: WindowPtr
  var renderer: RendererPtr
  var evt = defaultEvent
  if init(INIT_VIDEO) == SdlError:# getting a SIGSEGV here on WSL if DISPLAY is not set!?
    quit("Couldn't initialise SDL")
  if createWindowAndRenderer(cint(winWidth), cint(winHeight),
                             0, window, renderer) == SdlError:
    quit("SDL error: couldn't create a window or renderer")
  renderer.clear
  renderer.present
  window.raiseWindow

  echo "Starting main event loop"
  echo "You can stop (and restart) the simulation by clicking anywhere"
  var t0 = epochTime()
  var tlast = t0
  var stopped = false
  var runGame = true
  var numGen: int
  while runGame:
    while pollEvent(evt):
      case evt.kind:
        of QuitEvent:
          runGame = false
          break
        of MouseButtonDown:
          #var x, y: cint
          #discard getMouseState(x, y)
          #echo fmt"Mouse press at {x}x{y}"
          if stopped:
            echo "Continuing"
          else:
            echo fmt"Stopping at generation {numGen}"
          stopped = not stopped
        else:
          discard
    if stopped:
      continue
    renderer.updateWindow(world, cellSize)
    sleep(int(sleepSecs * 1000))
    #delay(uint32(sleepSecs * 1000))# same, also cannot capture events

    numGen += 1
    if numGen mod 100 == 0:
      let elapsed = epochTime() - tlast - sleepSecs/1000.0
      let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 3)
      tlast = epochTime()
      #let p = numCellsAlive(world)/(worldHeight*worldWidth)*100.0
      #echo fmt"Evolving generation {numGen}. Its world is {int(p)}% populated. Passed time: {elapsedStr}"
      echo fmt"Evolving generation {numGen}. Passed time: {elapsedStr} since last reported"

    if numGen == maxGenerations:
      break

    world.evolve(nextworld)

  let elapsed = epochTime() - t0 - sleepSecs/1000.0
  let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 3)
  echo fmt"Stopping at generation {numGen}. Total time: {elapsedStr}"

  sdl2.quit()


when isMainModule:
  import cligen;
  dispatch(gol,
           help = {
             "width" : "Window width",
             "height" : "Window height",
             "cellSize" : "Cell size in pixel",
             "withBorder" : "World has border",
             "sleepSecs" : "Seconds to sleep between steps",
             "density" : "Initial population density",
             "maxGenerations": "Stop after this many generations",
             "rleFile": "RLE file to read (overwrites winWidth, winHeight, withBorder and ignores desnity)",
             "rlePadding": "Add some padding to RLE pattern"},
           short = {
             "width" : 'x',
             "height" : 'y',
             "cellSize" : 'c',
             "withBorder" : 'b',
             "sleepSecs" : 's',
             "density" : 'd',
             "maxGenerations": 'm',
             "rleFile": 'f',
             "rlePadding": 'p'},)
