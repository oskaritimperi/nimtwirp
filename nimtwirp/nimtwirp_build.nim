import os
import osproc
import strformat
import strutils
import parseopt2

import nimpb/compiler/compiler
import generator

proc usage() {.noreturn.} =
    echo(&"""
{getAppFilename()} --out=OUTDIR [-IPATH [-IPATH]...] PROTOFILE...

    --out       The output directory for the generated files
    -I          Add a path to the set of include paths
    --prefix    The URL prefix used for service (default: /twirp/)
""")
    quit(QuitFailure)

var includes: seq[string] = @[]
var protos: seq[string] = @[]
var outdir: string
var prefix: string = "/twirp/"

for kind, key, val in getopt():
    case kind
    of cmdArgument:
        add(protos, key)
    of cmdLongOption, cmdShortOption:
        case key
        of "help", "h": usage()
        of "prefix": prefix = val
        of "out": outdir = val
        of "I": add(includes, val)
        else:
            echo("error: unknown option: " & key)
            usage()
    of cmdEnd: assert(false)

if outdir == "":
    echo("error: --out is required")
    quit(QuitFailure)

if len(protos) == 0:
    echo("error: no input files")
    quit(QuitFailure)

compileProtos(protos, includes, outdir, newTwirpServiceGenerator(prefix))
