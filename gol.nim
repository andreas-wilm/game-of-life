import os
import random
import sequtils
import strformat
import osproc
import colors

import cligen
import sdl2


type Cell = bool

type World = object
  height: int
  width: int
  matrix: seq[seq[Cell]]
  borderless: bool


randomize()


proc setCellStatus(w: var World, row: int, col: int, alive: bool) =
  assert row < w.height and col < w.width
  w.matrix[row][col] = alive


proc cellIsAlive(w: World, row: int, col: int): bool =
  assert row < w.height and col < w.width
  return w.matrix[row][col]


# FIXME delete after REL import is implemtented
proc initWorldWithOneGlider(w: var World) =
  assert w.height >= 3 and w.width >= 3
  for r in 0..<w.height:
    for c in 0..<w.width:
      setCellStatus(w, r, c, false)
  let startRow = (w.height div 2) - 1
  let startCol = (w.width div 2) - 1
  # is there an easier way to do this?
  setCellStatus(w, startRow+1, startCol+1, true)
  setCellStatus(w, startRow+2, startCol+3, true)
  setCellStatus(w, startRow+3, startCol+1, true)
  setCellStatus(w, startRow+3, startCol+2, true)
  setCellStatus(w, startRow+3, startCol+3, true)


proc populateWorld(w: var World, density = 0.25) =
  var s = 0
  for r in 0..<w.height:
    for c in 0..<w.width:
      let isAlive = bool(rand(1.0) < density)
      setCellStatus(w, r, c, isAlive)
      if isAlive:
        inc s
  let d = float(s)/(float(w.height)*float(w.width))*100.0
  echo fmt"World is {d:.2f}% populated"


proc createNewWorld(height, width: int, borderless = false): World =
  result.height = height
  result.width = width
  # or type Matrix[W, H: static[int]] = array[1..W, array[1..H, int]]
  # result = array[1..height, array[1..width, Cell]]
  # (from https://nim-by-example.github.io/arrays/)
  # but couldn't figure out how to use this easily
  # during definition (dim not known) and passing around (openarray of openarray)
  result.matrix = newSeqWith(height, newSeq[Cell](width))
  result.borderless = borderless


proc countLiveNeighbours(w: World, row: int, col: int): int =
  assert row < w.height and col < w.width
  var nrow, ncol: int
  var isAlive: bool
  let neighbourOffsets = [[-1, 1],  [0, 1],  [1, 1],
                          [-1, 0],           [1, 0],
                          [-1, -1], [0, -1], [1, -1]]

  for (roff, coff) in neighbourOffsets:
    # coordinates for neighbouring cell to inspect
    nrow = row + roff
    ncol = col + coff

    if w.borderless:
      # adjust for border cases
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
      # FIXME this has weird side effects, for example
      # a glider leaving the screen leaves behind a still square of 4
      if nrow == -1 or nrow == w.height:
        isAlive = false
      elif ncol == -1 or ncol == w.width:
        isAlive = false
      else:
        isAlive = cellIsAlive(w, nrow, ncol)

    result += int(isAlive)
  assert(result >= 0 and result <= 8)


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
  var rgbAlive = extractRGB(colLightGreen)
  var rgbDead = extractRGB(colBlack)

  for row in 0..<world.height:
    for col in 0..<world.width:
      var r, g, b: uint8
      if cellIsAlive(world, row, col):
        # FIXME r, g, b are ranges, why?
        r = uint8(rgbAlive[0])
        g = uint8(rgbAlive[1])
        b = uint8(rgbAlive[2])
      else:
        # FIXME r, g, b are ranges, why?
        r = uint8(rgbDead[0])
        g = uint8(rgbDead[1])
        b = uint8(rgbDead[2])
      renderer.setDrawColor(r, g, b, alpha)

      for i in 1..cellSize:
        for j in 1..cellSize:
          renderer.drawPoint(cint(col * cellSize + i),
                             cint(row * cellSize + j))
  renderer.present


proc gol(winWidth = 640, winHeight = 480, cellSize = 2,
         withBorder = false, sleepSecs = 0.01, density = 0.25): int =
  ## cellSize = pixels per cell and hence determining world dimension
  var numGen: int
  var window: WindowPtr
  var renderer: RendererPtr
  var evt = defaultEvent
  var runGame = true

  if cellSize*3 > min(winWidth, winHeight):
    quit("Cell size too big for screen")

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
  echo fmt"DEBUG worldWidth {worldWidth} worldHeight {worldHeight}"
  var world = createNewWorld(worldHeight, worldWidth, not withBorder)
  var nextWorld = createNewWorld(worldHeight, worldWidth, not withBorder)

  populateWorld(world, density)
  #initWorldWithOneGlider(world)

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
      echo fmt"Evolving generation {numGen}..."
    for r in 0..<world.height:
      for c in 0..<world.width:
        var s = cellAliveInNextGen(world, r, c)
        setCellStatus(nextWorld, r, c, s)
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
             "withBorder" : "With border",
             "sleepSecs" : "Seconds to sleep between steps",
             "density" : "Initial population density"},
             )
