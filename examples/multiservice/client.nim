import os
import strformat
import strutils
import parseopt

import fooservice_pb
import fooservice_twirp

import barservice_pb
import barservice_twirp

var service = "foo"
var value: int

for kind, key, val in getopt():
    case kind
    of cmdArgument:
        value = parseInt(key)
    of cmdLongOption, cmdShortOption:
        case key
        of "foo", "bar": service = key
        else:
            echo("error: unknown option: " & key)
            quit(QuitFailure)
    of cmdEnd: assert(false)

if service == "foo":
    var req = newFooReq()
    req.a = int32(value)
    let client = newFooClient("http://localhost:8081")
    try:
        let resp = MakeFoo(client, req)
        echo(&"Response from foo: {resp.b}")
    except Exception as exc:
        echo(&"oh no: {exc.msg}")
else:
    var req = newBarReq()
    req.a = int32(value)
    let client = newBarClient("http://localhost:8081")
    try:
        let resp = MakeBar(client, req)
        echo(&"Response from bar: {resp.b}")
    except Exception as exc:
        echo(&"oh no: {exc.msg}")
