## module for parsing Game of Life RLE files. Not well tested.
#
# Author: Andreas Wilm
# License: MIT, see LICENSE

import strutils
import sequtils
import strformat


const DEFAULT_RULE = "B3/S23"


type Info* = object
  comments*: seq[string]
  name*: string
  authordate*: string
  topleftCoords*: string
  rule*: string


proc parseInfoSection(fh: File, info: var Info): string =
  ## sets ``info`` and returns unparsed/peeked next line
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
        info.rule = value.toUpperAscii
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

  if len(parts) < 2:
    raise newException(ValueError, fmt"Couldn't parse line '{line}'")
  let xeq = parts[0]
  let yeq = parts[1]
  if len(parts) == 3:
    let ruleeq = parts[2]
    assert ruleeq.startsWith("rule=")
    assert ruleeq.count("=") == 1
    rule = ruleeq.split("=", maxsplit=2)[1].toUpperAscii

  assert xeq.startsWith("x=")
  assert xeq.count("=") == 1
  width = parseInt(xeq.split("=", maxsplit=2)[1])

  assert yeq.startsWith("y=")
  assert yeq.count("=") == 1
  height = parseInt(yeq.split("=", maxsplit=2)[1])

  return (height, width, rule)


# debugging
proc printcells(cells: var seq[seq[bool]]) =
    for row in cells:
      var rowStr = ""
      for v in row:
        if v:
          rowStr.add("O")
        else:
          rowStr.add(".")
      echo rowStr


proc parseRLESection(fh: File, cells: var seq[seq[bool]], padding = 0) =
  ## parses RLE from ``fh`` and sets (preallocated) ``cells`` accordingly
  # <run><tag>
  # if run is missing run=1
  # b dead
  # o alive
  # $ end of line
  # stop parsing after !
  var runLengthStr: string
  var runLength: int
  var numRow = padding
  var numCol = padding

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
          numCol = padding
        elif c == '!':
          break
        runLengthStr = ""# reset
        runLength = 0# reset
      elif isdigit(c):
        runLengthStr.add(c)# keep adding
        runLength = parseInt(runLengthStr)
      else:
        raise newException(ValueError, fmt"Unknown letter '{c}' in RLE string '{line}'")


proc parseRLEFile*(fn: string, padding = 0): (seq[seq[bool]], Info) =
    ## main entry point: parse rle file ``fn`` and return cells as 2d sequence.
    ## optionally add some padding.
    var info: Info# returned
    var cells: seq[seq[bool]]# returned
    var height, width: int
    var fh = open(fn, fmRead)
    try:
      let unparsedLine = parseInfoSection(fh, info)
      #echo fmt"DEBUG: info = {info}"
      #echo fmt"DEBUG: unparsed header line = {unparsedLine}"
      var headerRule: string
      (height, width, headerRule) =
        parseHeaderLine(unparsedLine)

      # rule can be defined in info or header, so consolidate
      if len(info.rule) > 0:
        assert len(headerRule) == 0
      elif len(headerRule) > 0:
        info.rule = headerRule
      else:
        info.rule = DEFAULT_RULE

      # init "cells" now that we know the dimensions
      # and parse the actual coordinates
      cells = newSeqWith(height+2*padding, newSeq[bool](width+2*padding))
      parseRLESection(fh, cells, padding)
      #printcells(cells)
      # rest discarded according to spec

    except IOError:
      # propagate exception up?
      quit(fmt"Premature end of file in {fn}")

    return (cells, info)


when isMainModule:
    var cells: seq[seq[bool]]
    var info: Info
    (cells, info) = parseRLEFile("patterns/wilma.rle")
    printcells(cells)
