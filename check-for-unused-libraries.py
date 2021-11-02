#!/usr/bin/env python
#
# Check for unused libraries in a MSVC link .map file (or 'link.tmp').
# Prints with colours using 'colorama' (if available).
#
import os, sys

ignore_libs = [ "oldnames.lib", "crypt32.lib", "advapi32.lib" ]

class State():
  IDLE   = 0
  UNUSED = 1

try:
  from colorama import init, Fore, Style
  init()

  class Colour():
    RESET = Style.RESET_ALL
    RED   = Fore.RED   + Style.BRIGHT
    WHITE = Fore.WHITE + Style.BRIGHT
except:
  class Colour():
    RESET = RED = WHITE = ""

def Print (color, s):
  print ("%s%s%s" % (color, s, Colour.RESET))

def report (map_file, unused):
  num = len(unused)
  if num > 0:
    Print (Colour.RED, "%d unused %s in %s:" % (num, ["library", "libraries"][num > 1], map_file))
    for u in unused:
      print ("  " + u)
  Print (Colour.WHITE, "Done.\n")

def process_map (file, state):
  unused_libs = []
  with open (file, "rt") as f:
    lines = f.readlines()
    for l in lines:
      l = l.strip()
      if l == "Unused libraries:":
        state = State.UNUSED
        continue
      if state == State.UNUSED:
        if l == "":
          break
        if os.path.basename (l).lower() not in ignore_libs:
          unused_libs.append (l)
  return unused_libs

map_file = sys.argv[1]
unused = process_map (map_file, State.IDLE)
report (map_file, unused)
