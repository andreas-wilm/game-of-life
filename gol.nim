import os
import random
import sequtils
import strformat
import osproc
import colors

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


proc initWorldWithOneGlider(w: var World) =
  assert w.height >= 3 and w.width >= 3
  for r in 0..<w.height:
    for c in 0..<w.width:
      setCellStatus(w, r, c, false)
  var startRow = (w.height div 2) - 1
  var startCol = (w.width div 2) - 1
  # is there an easier way to do this?
  setCellStatus(w, startRow+1, startCol+1, true)
  setCellStatus(w, startRow+2, startCol+3, true)
  setCellStatus(w, startRow+3, startCol+1, true)
  setCellStatus(w, startRow+3, startCol+2, true)
  setCellStatus(w, startRow+3, startCol+3, true)


proc initWorld(w: var World) =
  for r in 0..<w.height:
    for c in 0..<w.width:
      var isAlive = bool(rand(0..1))
      setCellStatus(w, r, c, isAlive)


proc createNewWorld(height, width: int, borderless = false): World =
  result.height = height
  result.width = width
  # or type Matrix[W, H: static[int]] = array[1..W, array[1..H, int]]
  # from https://nim-by-example.github.io/arrays/
  # couldn't figure out how to use
  # result = array[1..height, array[1..width, Cell]]
  # during definition and passing around
  result.matrix = newSeqWith(height, newSeq[Cell](width))
  result.borderless = borderless


proc cellAliveInNextGen(isAlive: bool, numLiveNeighbours: int): bool =
  if isAlive == true:
    # 0..1:# lonely
    if numLiveNeighbours in 2..3:# just right
      return true
    # 4..8:# overcrowded
  else:
    if numLiveNeighbours == 3:# give birth
      return true
    # else:# barren
  return false


proc cellIsAlive(w: World, row: int, col: int): bool =
  return w.matrix[row][col]


proc countLiveNeighbours(w: World, row: int, col: int): int =
  assert row < w.height and col < w.width
  var nrow, ncol: int
  var isAlive: bool

  # row and col should be zero based
  for roff in @[-1, 0, 1]:
    for coff in @[-1, 0, 1]:
      # skip self
      if roff == 0 and coff == 0:
        continue
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
        # FIXME this can create weird side effects
        # where for example a glider leaving the screen
        # leaves behind a still square of 4 cells
        if nrow == -1 or nrow == w.height:
          isAlive = false
        elif ncol == -1 or ncol == w.width:
          isAlive = false
        else:
          isAlive = cellIsAlive(w, nrow, ncol)

      result += int(isAlive)
  assert(result >= 0 and result <= 8)


proc initWindow(height, width: int): RendererPtr =
  var
    window: WindowPtr
    renderer: RendererPtr
    evt = defaultEvent

  if init(INIT_VIDEO) == SdlError:
    quit("Couldn't initialise SDL")
  if createWindowAndRenderer(cint(width), cint(height),
                             0, window, renderer) == SdlError:
    quit("SDL error: couldn't create a window or renderer")
  discard pollEvent(evt)
  renderer.clear
  renderer.present
  return renderer


proc updateWindow(renderer: RendererPtr, world: World, worldToWinRatio: int) =
  let alpha = uint8(255)
  var rgbAlive = extractRGB(colGreen)
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

      for i in 1..worldToWinRatio:
        for j in 1..worldToWinRatio:
          renderer.drawPoint(cint(col * worldToWinRatio + i), cint(row * worldToWinRatio + j))
  renderer.present


proc updateScreenTerminal(w: World) =
  discard execCmd "clear"
  var rowStr = ""
  for r in 0..<w.height:
    for c in 0..<w.width:
      var status = ' '
      if cellIsAlive(w, r, c):
        status = 'O'
      rowStr.add(status)
    rowStr.add("|")
    echo rowStr
    rowStr = ""
  for c in 0..<w.width:
    rowStr.add("-")
  # this alternative complaints about seq use instead of string?:
  #   rowStr.add("-".repeat(w.width))
  echo rowStr


when isMainModule:
  let winWidth = 640
  let winHeight = 480
  let worldToWinRatio = 4
  let sleepSecs = 0.01
  let borderless = true
  var numGen: int

  assert winWidth mod worldToWinRatio == 0
  assert winHeight mod worldToWinRatio == 0

  echo "Creating world"
  var world = createNewWorld(int(winHeight/worldToWinRatio),
                             int(winWidth/worldToWinRatio), borderless)
  var nextWorld = createNewWorld(int(winHeight/worldToWinRatio),
                                int(winWidth/worldToWinRatio), borderless)
  echo "Initializing world"
  initWorld(world)
  #initWorldWithOneGlider(world)

  var renderer = initWindow(winHeight, winWidth)
  while true:
    numGen += 1
    if numGen mod 10 == 0:
      echo fmt"Evolving generation {numGen}..."
    for r in 0..<world.height:
      for c in 0..<world.width:
        var p = cellIsAlive(world, r, c)
        var n = countLiveNeighbours(world, r, c)
        var f1 = cellAliveInNextGen(p, n)
        setCellStatus(nextWorld, r, c, f1)
        #echo fmt"DEBUG iteration {i}: cell {r}:{c}={p} has {n} neighbours: {f1}"
    #echo "DEBUG: updating screen"
    updateWindow(renderer, world, worldToWinRatio)
    sleep(int(sleepSecs * 1000))
    world = nextWorld

  # ?
  renderer.destroy()
  #window.destroy()
  sdl2.quit()