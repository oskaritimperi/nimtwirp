import asynchttpserver
import asyncdispatch
import random

import nimtwirp/nimtwirp
import nimtwirp/errors

import fooservice_pb
import fooservice_twirp

import barservice_pb
import barservice_twirp

proc MakeFooImpl(service: Foo, req: FooReq): Future[FooResp] {.async.} =
    result = newFooResp()
    result.b = req.a * 2

proc MakeBarImpl(service: Bar, req: BarReq): Future[BarResp] {.async.} =
    result = newBarResp()
    result.b = req.a * 3

var
    foo {.threadvar.}: Foo
    bar {.threadvar.}: Bar

foo = newFoo()
foo.MakeFooImpl = MakeFooImpl

bar = newBar()
bar.MakeBarImpl = MakeBarImpl

# You need to declare `nimtwirp.Settings`, which you must pass to
# `twirpServices`. You must create a variable, because the twirpServices macro
# will refer to this variable in the code it generates.
var settings = nimtwirp.newSettings(Port(8081))

twirpServices(settings):
    foo
    bar

runForever()
