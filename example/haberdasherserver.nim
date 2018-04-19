import asynchttpserver
import asyncdispatch
import random

import nimtwirp/errors
import nimtwirp/response

import service_pb
import service_twirp

proc MakeHatImpl(service: Haberdasher, size: twirp_example_haberdasher_Size): twirp_example_haberdasher_Hat =
    if size.inches <= 0:
        raise newTwirpError(TwirpInvalidArgument, "I can't make a hat that small!")

    result = newtwirp_example_haberdasher_Hat()
    result.inches = size.inches
    result.color = rand(["white", "black", "brown", "red", "blue"])
    result.name = rand(["bowler", "baseball cap", "top hat", "derby"])

var
    server = newAsyncHttpServer()
    service {.threadvar.}: Haberdasher

service = newHaberdasher()
service.MakeHatImpl = MakeHatImpl

proc cb(req: Request) {.async.} =
    var resp = HaberdasherHandler(service, req)
    await respond(req, resp)

waitFor server.serve(Port(8080), cb)
