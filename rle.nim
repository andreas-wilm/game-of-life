#import io
#import system
#import re
import strutils
import sequtils
import strformat

const DEFAULT_RULE = "B3/S23"


type Info* = object
  comments: seq[string]
  name: string
  authordate: string
  topleftCoords: string
  rule: string


type World* = object
  height: int
  width: int
  cells: seq[seq[bool]]
  info: Info


proc parseInfoSection(fh: File, info: var Info): string =
  ## sets ``info`` and returns unparsed line
  for line in lines(fh):
    # detect end
    if not line.startsWith("#"):
        result = line
        break
    assert len(line)>2
    let letter = line[1]
    let value = line[2..^1].strip()
    case letter:
      of 'C', 'c':
        info.comments.add(value)
      of 'N':
        assert len(info.name) == 0
        info.name = value
      of 'O':
        assert len(info.authordate) == 0
        info.authordate = value
      of 'P', 'R':
        assert len(info.topleftCoords) == 0
        info.topleftCoords = value
      of 'r':
        assert len(info.rule) == 0
        info.rule = value
      else:
        raise newException(ValueError, fmt"Unknown info line letter '{letter}'")


proc parseHeaderLine(line: TaintedString): (int, int, string) =
  ## parses header line: x = m, y = n[, rule = abc]
  ##  returns (height, width, rule)
  var height = 0
  var width = 0
  var rule = ""

  # strip for easier parsing and leniency
  var parts = line.replace(" ", "").split(",", maxsplit=3)
  echo fmt"DEBUG: has {len(parts)} parts"

  if len(parts) < 2:
    raise newException(ValueError, fmt"Couldn't parse line '{line}'")
  let xeq = parts[0]
  let yeq = parts[1]
  if len(parts) == 3:
    let ruleeq = parts[2]
    assert ruleeq.startsWith("rule=")
    assert ruleeq.count("=") == 1
    rule = ruleeq.split("=", maxsplit=2)[1]

  assert xeq.startsWith("x=")
  assert xeq.count("=") == 1
  width = parseInt(xeq.split("=", maxsplit=2)[1])

  assert yeq.startsWith("y=")
  assert yeq.count("=") == 1
  height = parseInt(yeq.split("=", maxsplit=2)[1])

  return (height, width, rule)


proc printcells(cells: var seq[seq[bool]]) =
    for row in cells:
      var rowStr = ""
      for v in row:
        if v:
          rowStr.add("O")
        else:
          rowStr.add(".")
      echo rowStr


proc parseRLESection(fh: File, cells: var seq[seq[bool]]) =
  ## parses RLE from ``fh`` and sets (preallocated) ``cells`` accordingly
  # <run><tag>, if run is missing run=1
  # b dead
  # o alive
  # $ end of line
  # stop parsing after discovering !
  var runLengthStr: string
  var runLength: int
  var numRow, numCol: int

  for line in lines(fh):
    for c in line:
      if c in "bo$!":
        #echo fmt"DEBUG WxH={len(cells)}x{len(cells[0])} numRow={numRow} numCol={numCol} c={c}"
        if c in "bo":
          var lives = true
          if c == 'b':
            lives = false
          if runLength == 0:
            runLength = 1# warning: overwriting, but immediate reset below
          #echo fmt"DEBUG row {numRow}: setting next {runLength}x ({numCol}..{numCol+runLength}) to {lives}"
          for i in numCol..<numCol+runLength:
            cells[numRow][i] = lives
          inc(numCol, runLength)
        elif c == '$':
          inc numRow
          numCol = 0
        elif c == '!':
          break
        runLengthStr = ""# reset
        runLength = 0# reset
      elif isdigit(c):
        runLengthStr.add(c)# keep adding
        runLength = parseInt(runLengthStr)
      else:
        raise newException(ValueError, fmt"Unknown letter '{c}' in RLE string '{line}'")


proc parseRLEFile(fn: string): World =
    var fh = open(fn, fmRead)

    try:
      let unparsedLine = parseInfoSection(fh, result.info)
      echo fmt"DEBUG: info = {result.info}"
      echo fmt"DEBUG: unparsed header line = {unparsedLine}"
      var headerRule: string
      (result.height, result.width, headerRule) =
        parseHeaderLine(unparsedLine)

      # rule can be defined in info or header, so consolidate
      if len(result.info.rule) > 0:
        assert len(headerRule) == 0
      elif len(headerRule) > 0:
        result.info.rule = headerRule
      else:
        result.info.rule = DEFAULT_RULE

      # init "cells" now that we know the dimensions
      # and parse the actual coordinates
      result.cells = newSeqWith(result.height,
                                 newSeq[bool](result.width))
      parseRLESection(fh, result.cells)
      echo fmt"DEBUG:..."
      printcells(result.cells)
      # rest discarded according to spec

    except IOError:
      quit(fmt"Premature end of file in {fn}")


when isMainModule:
    discard parseRLEFile("patterns/wilma.rle")