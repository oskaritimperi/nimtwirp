import os
import strformat
import strutils

import service_pb
import service_twirp

if paramCount() != 1:
    echo("usage: " & getAppFilename() & " <size>")
    quit(QuitFailure)

var size = newtwirp_example_haberdasher_Size()
try:
    size.inches = parseInt(paramStr(1)).int32
except:
    echo("invalid size")
    quit(QuitFailure)

let client = newHaberdasherClient("http://localhost:8080")

try:
    let hat = MakeHat(client, size)
    echo(&"I have a nice new hat: {hat.inches} inch {hat.color} {hat.name}")
except Exception as exc:
    echo(&"oh no: {exc.msg}")
