import os
import random
import sequtils
import strformat
import osproc

type Cell = bool

type Screen = bool

type World = object
  height: int
  width: int
  matrix: seq[seq[Cell]]


randomize()



proc setCellStatus(w: var World, row: int, col: int, alive: bool) =
  assert row < w.height and col < w.width
  w.matrix[row][col] = alive


proc initWorld(w: var World) =
  for r in 0..<w.height:
    for c in 0..<w.width:
      var lives = bool(rand(0..1))
      setCellStatus(w, r, c, lives)
      discard


proc createNewWorld(height, width: int): World =
  result.height = height
  result.width = width
  # or type Matrix[W, H: static[int]] = array[1..W, array[1..H, int]]
  # from https://nim-by-example.github.io/arrays/
  #result = array[1..height, array[1..width, Cell]]
  # too inflexible with handing around
  result.matrix = newSeqWith(height, newSeq[Cell](width))


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
  # row and col should be zero based
  for roff in @[-1, 0, 1]:
    for coff in @[-1, 0, 1]:
      # skip self
      if roff == 0 and coff == 0:
        continue
      # coordinates for neighbouring cell to inspect
      nrow = row + roff
      ncol = col + coff

      # adjust for border cases
      if nrow == -1:
        nrow = w.height - 1
      elif nrow == w.height:
        nrow = 0
      if ncol == -1:
        ncol = w.width - 1
      elif ncol == w.width:
        ncol = 0

      result += int(cellIsAlive(w, nrow, ncol))
  assert(result >= 0 and result <= 8)


proc initScreen(): Screen =
  result = true


proc updateScreen(s: Screen, w: World) =
  discard execCmd "clear"
  var rowStr = ""
  for r in 0..<w.height:
    for c in 0..<w.width:
      var status = ' '
      if cellIsAlive(w, r, c):
        status = 'O'
      rowStr.add(status)
    echo rowStr
    rowStr = ""


when isMainModule:
  let width = 75
  let height = 25
  let maxIter = 1000
  let sleepSecs = 0.1
  var world = createNewWorld(height, width)
  var nextWorld = createNewWorld(height, width)
  var screen = initScreen()
  initWorld(world)

  # evolve
  for i in 1..maxIter:
    for r in 0..<height:
      for c in 0..<width:
        var p = cellIsAlive(world, r, c)
        var n = countLiveNeighbours(world, r, c)
        var f1 = cellAliveInNextGen(p, n)
        setCellStatus(nextWorld, r, c, f1)
        #echo fmt"iteration {i}: cell {r}:{c}={p} has {n} neighbours: {f1}"
    updateScreen(screen, world)
    world = nextWorld
    sleep(int(sleepSecs * 1000))


