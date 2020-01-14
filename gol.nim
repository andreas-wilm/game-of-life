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


type World = object
  height: int
  width: int
  cells: seq[seq[bool]]# true == alive
  color: seq[seq[colors.Color]]
  borderless: bool


const COLORS = @[colRed, colYellow, colBlue, colGreen, colOrange, colPurple]


randomize()


proc numCellsAlive(w: World): int =
  # while intuitive, there surely must be a cleverer way?
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
      var c = colBlack
      if isAlive:
        c = sample(COLORS)
      world.cells[row][col] = isAlive
      world.color[row][col] = c


proc createNewWorld(height, width: int, borderless = false): World =
  ## creates a new world, which is empty. call populate() or
  ## set status for all cells afterwards.
  result.height = height
  result.width = width
  result.cells = newSeqWith(height, newSeq[bool](width))
  result.color = newSeqWith(height, newSeq[colors.Color](width))
  result.borderless = borderless


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


proc countLiveNeighbours(world: World, row: int, col: int): int {.inline.} =
  return len(getLiveNeighbourCoords(world, row, col))


proc mostCommonNeighbourColor(world: World, row: int, col: int): colors.Color =
  ## returns color most common in neighbouring cells that are alive.
  ## choses color randomly from the list on ties.
  var liveColors = initCountTable[colors.Color]()
  for (row, col) in getLiveNeighbourCoords(world, row, col):
    liveColors.inc(world.color[row][col])
  result = liveColors.largest[0]


proc cellAliveInNextGen(world: World, row: int, col: int): bool =
  ## determine whether cell will live in next generation
  let currentlyAlive = world.cells[row][col]
  let numLiveNeighbours = countLiveNeighbours(world, row, col)
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
  ## draws update of all cells
  let alpha = uint8(255)
  for row in 0..<world.height:
    for col in 0..<world.width:
      let rgb = extractRGB(world.color[row][col])
      let r = uint8(rgb[0])
      let g = uint8(rgb[1])
      let b = uint8(rgb[2])
      renderer.setDrawColor(r, g, b, alpha)
      # draw a square with dimension cellSize
      for i in 1..cellSize:
        for j in 1..cellSize:
          renderer.drawPoint(cint(col * cellSize + i),
                             cint(row * cellSize + j))
  renderer.present


proc evolve(world: var World, nextWorld: var World) =
  ## evolve the current world and saves results in nextWorld
  for row in 0..<world.height:
    for col in 0..<world.width:
      let isAlive = world.cells[row][col]
      let willLive = cellAliveInNextGen(world, row, col)
      var c = world.color[row][col]# default to keep color
      if willLive and not isAlive:
        # just born? apply most common color
        c = mostCommonNeighbourColor(world, row, col)
      elif not willLive and isAlive:
        # just deceased? shade
        c = intensity(c, 0.2)
      nextWorld.cells[row][col] = willLive
      nextWorld.color[row][col] = c
  world = nextWorld


proc gol(winWidth = 640, winHeight = 480, cellSize = 4,
         withBorder = false, sleepSecs = 0.0, density = 0.15,
         maxGenerations = -1): int =
  ## main function. meaning of arguments is described below in
  ## cligen interface.

  if cellSize*3 > min(winWidth, winHeight):
    quit("Cell size too big for screen")

  echo "Setting up Window"
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

  echo "Creating world"
  let worldWidth = winWidth div cellSize
  let worldHeight = winHeight div cellSize
  #echo fmt"DEBUG worldWidth {worldWidth} worldHeight {worldHeight}"
  var world = createNewWorld(worldHeight, worldWidth, not withBorder)
  var nextWorld = deepCopy(world)
  world.populate(density)

  echo "Starting main event loop"
  echo "You can stop (and restart) the simulation by clicking anywhere"
  var t0 = epochTime()
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
            echo "Stopping"
          stopped = not stopped
        else:
          discard
    if stopped:
      continue
    renderer.updateWindow(world, cellSize)
    sleep(int(sleepSecs * 1000))

    numGen += 1
    if numGen mod 100 == 0:
      let elapsed = epochTime() - t0 - sleepSecs/1000.0
      let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 3)
      t0 = epochTime()
      let p = numCellsAlive(world)/(worldHeight*worldWidth)*100.0
      echo fmt"Evolving generation {numGen}. Its world is {int(p)}% populated. Passed time: {elapsedStr} "

    if numGen == maxGenerations:
      break

    world.evolve(nextworld)

  renderer.destroy()
  window.destroy()


when isMainModule:
  import cligen;
  dispatch(gol,
           help = {
             "winWidth" : "Window width",
             "winHeight" : "Window height",
             "cellSize" : "Cell size in pixel",
             "withBorder" : "World has border",
             "sleepSecs" : "Seconds to sleep between steps",
             "density" : "Initial population density",
             "maxGenerations": "Stop after this many generations"},
           short = {
             "winWidth" : 'x',
             "winHeight" : 'y',
             "cellSize" : 'c',
             "withBorder" : 'b',
             "sleepSecs" : 's',
             "density" : 'd',
             "maxGenerations": 'm'},)
