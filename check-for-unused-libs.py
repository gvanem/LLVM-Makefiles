#!/usr/bin/env python
#
# Check for unused libraries in a MSVC link .map file.
# Prints in red colour using 'colorama'.
#
import os, sys, glob

try:
  from colorama import init, Fore, Style
  init()
  _RESET = Style.RESET_ALL
  _RED   = Fore.RED + Style.BRIGHT

except ImportError as e:
  _RESET = ""
  _RED   = ""

_IDLE       = 0
_UNUSED     = 1
ignore_libs = [ "uuid.lib", "oldnames.lib" ]

def report (map_file, unused):
  num = len(unused)
  plural = [ "library", "libraries" ]
  if num > 0:
    print ("%s%d unused %s in %s:%s" % (_RED, num, plural[num > 1], map_file, _RESET))
    for u in unused:
      print ("  " + u)

def process (file, state):
  unused_libs = []
  f = open (file, "rt")
  try:
    lines = f.readlines()
  except IOError:
    return []
  finally:
    f.close()

  for l in lines:
    l = l.strip()
    if l == "Unused libraries:":
      state = _UNUSED
      continue
    if state == _UNUSED:
      if l == "":
        break
      if os.path.basename(l).lower() not in ignore_libs:
        unused_libs.append (l)
  return unused_libs

for map_file in glob.glob (sys.argv[1]):
  unused = process (map_file, _IDLE)
  report (map_file, unused)

