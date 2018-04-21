import asynchttpserver
import asyncdispatch
import random

import nimtwirp/nimtwirp
import nimtwirp/errors

import service_pb
import service_twirp

proc MakeHatImpl(service: Haberdasher, size: twirp_example_haberdasher_Size): Future[twirp_example_haberdasher_Hat] {.async.} =
    if size.inches <= 0:
        raise newTwirpError(TwirpInvalidArgument, "I can't make a hat that small!")

    result = newtwirp_example_haberdasher_Hat()
    result.inches = size.inches
    result.color = rand(["white", "black", "brown", "red", "blue"])
    result.name = rand(["bowler", "baseball cap", "top hat", "derby"])

# You can do serving this way if you want to customize the process a bit

var
    server = newAsyncHttpServer()
    service {.threadvar.}: Haberdasher

service = newHaberdasher()
service.MakeHatImpl = MakeHatImpl

proc handler(req: Request) {.async.} =
    # Each service will have a generated handleRequest() proc which takes the
    # service object and a asynchttpserver.Request object and returns a
    # Future[nimtwirp.Response].
    var fut = handleRequest(service, req)
    yield fut
    if fut.failed:
        await respond(req, nimtwirp.newResponse(fut.readError()))
    else:
        await respond(req, fut.read())

waitFor server.serve(Port(8080), handler)

# Or this way (idea copied from Jester) if your needs are simple.
#
#var settings = newSettings(8080)
#twirpServices(settings):
#    service
#runForever()
