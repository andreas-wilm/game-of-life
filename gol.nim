import os
import random
import sequtils
import strformat
import strutils
import osproc
import colors
import tables
import cligen
import times

import sdl2


type Cell = object
  alive: bool
  color: colors.Color

type World = object
  height: int
  width: int
  matrix: seq[seq[Cell]]
  borderless: bool


const COLORS = @[colRed, colYellow, colBlue, colGreen, colOrange, colPurple]


randomize()


# FIXME too many args
proc setCellStatus(w: var World, row: int, col: int,
                   alive: bool, color: colors.Color) =
  assert row < w.height and col < w.width
  var cell = addr w.matrix[row][col]# addr! oterhwise this becomes a copy
  cell.alive = alive
  cell.color = color


proc cellIsAlive(w: World, row: int, col: int): bool =
  assert row < w.height and col < w.width
  return w.matrix[row][col].alive


proc getCellColor(w: World, row: int, col: int): colors.Color =
  assert row < w.height and col < w.width
  return w.matrix[row][col].color


proc numCellsAlive(w: World): int =
  # there surely must be a cleverer way? maybe map, but how for 2d with custom types?
  for r in 0..<w.height:
    for c in 0..<w.width:
      if cellIsAlive(w, r, c):
        inc result


proc populateWorld(world: var World, density = 0.25) =
  for row in 0..<world.height:
    for col in 0..<world.width:
      let isAlive = bool(rand(1.0) < density)
      var c = colBlack
      if isAlive:
        c = sample(COLORS)
      setCellStatus(world, row, col, isAlive, c)


proc createNewWorld(height, width: int, borderless = false): World =
  result.height = height
  result.width = width
  result.matrix = newSeqWith(height, newSeq[Cell](width))
  result.borderless = borderless


proc getLiveNeighbourCoords(w: World, row: int, col: int): seq[(int, int)] =
  var nrow, ncol: int# neighbour coordinates
  var isAlive: bool
  let neighbourOffsets = [[-1, 1],  [0, 1],  [1, 1],
                          [-1, 0],           [1, 0],
                          [-1, -1], [0, -1], [1, -1]]

  for (roff, coff) in neighbourOffsets:
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
      isAlive = cellIsAlive(w, nrow, ncol)
    else:
      # this has weird side effects, for example
      # a glider leaving the screen leaves behind a still square of 4
      if nrow == -1 or nrow == w.height:
        isAlive = false
      elif ncol == -1 or ncol == w.width:
        isAlive = false
      else:
        isAlive = cellIsAlive(w, nrow, ncol)

    if isAlive:
      result.add((nrow, ncol))


proc countLiveNeighbours(world: World, row: int, col: int): int =
  return len(getLiveNeighbourCoords(world, row, col))


proc mostCommonNeighbourColor(world: World, row: int, col: int): colors.Color =
  var liveColors = initCountTable[colors.Color]()
  for (row, col) in getLiveNeighbourCoords(world, row, col):
    liveColors.inc(getCellColor(world, row, col))
  result = liveColors.largest[0]


proc cellAliveInNextGen(world: World, row: int, col: int): bool =
  let currentlyAlive = cellIsAlive(world, row, col)
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
  let alpha = uint8(255)
  for row in 0..<world.height:
    for col in 0..<world.width:
      var r, g, b: uint8
      let rgb = extractRGB(getCellColor(world, row, col))
      r = uint8(rgb[0])
      g = uint8(rgb[1])
      b = uint8(rgb[2])
      renderer.setDrawColor(r, g, b, alpha)
      # draw a square with dimension cellSize
      for i in 1..cellSize:
        for j in 1..cellSize:
          renderer.drawPoint(cint(col * cellSize + i),
                             cint(row * cellSize + j))
  renderer.present


# main function
proc gol(winWidth = 640, winHeight = 480, cellSize = 4,
         withBorder = false, sleepSecs = 0.0, density = 0.15,
         maxGenerations = -1): int =
  ## cellSize = pixels per cell and hence determining world dimension
  var numGen: int
  var window: WindowPtr
  var renderer: RendererPtr
  var evt = defaultEvent
  var runGame = true

  if cellSize*3 > min(winWidth, winHeight):
    quit("Cell size too big for screen")

  echo "Setting up Window"
  if init(INIT_VIDEO) == SdlError:
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
  populateWorld(world, density)

  echo "Starting main event loop"
  var t0 = epochTime()
  while runGame:
    updateWindow(renderer, world, cellSize)
    sleep(int(sleepSecs * 1000))
    while pollEvent(evt):
      case evt.kind:
        of QuitEvent:
          runGame = false
          break
        of MouseButtonDown:
          var x, y: cint
          discard getMouseState(x, y)
          echo fmt"Mouse press at {x}x{y}"
        else:
          discard

    numGen += 1
    if numGen mod 100 == 0:
      let elapsed = epochTime() - t0
      let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 3)
      t0 = epochTime()
      let p = numCellsAlive(world)/(worldHeight*worldWidth)*100.0
      echo fmt"Evolving generation {numGen}. Its world is {int(p)}% populated. Time taken: {elapsedStr} "

    if numGen == maxGenerations:
      break

    # evolve
    for row in 0..<world.height:
      for col in 0..<world.width:
        let isAlive = cellIsAlive(world, row, col)
        let willLive = cellAliveInNextGen(world, row, col)
        var c = getCellColor(world, row, col)# default to keep color
        if willLive and not isAlive:
          # just born? apply most common color
          c = mostCommonNeighbourColor(world, row, col)
        elif not willLive and isAlive:
          # just deceased? shade
          c = intensity(c, 0.2)
        setCellStatus(nextWorld, row, col, willLive, c)

    world = nextWorld

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
             "maxGenerations": 'm'},
             )
