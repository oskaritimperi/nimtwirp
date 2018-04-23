import asyncdispatch
import asynchttpserver
import httpclient
import json
import macros
import strformat

import errors

type
    Settings* = ref object
        port*: Port
        address*: string

    Response* = ref object
        code*: HttpCode
        body*: string
        headers*: HttpHeaders

    ServeHandlerProc = proc (request: asynchttpserver.Request): Future[nimtwirp.Response] {.gcsafe, closure.}

    Client* = ref object of RootObj
        client*: HttpClient
        address*: string

proc respond*(req: asynchttpserver.Request, resp: nimtwirp.Response): Future[void] =
    req.respond(resp.code, resp.body, resp.headers)

proc newResponse*(exc: ref Exception): nimtwirp.Response =
    var twirpExc: TwirpErrorRef

    if exc of TwirpErrorRef:
        twirpExc = TwirpErrorRef(exc)
    else:
        twirpExc = newTwirpError(TwirpInternal, exc.msg)

    new(result)
    result.code = twirpExc.httpStatus
    result.body = $twirpErrorToJson(twirpExc)
    result.headers = newHttpHeaders({"Content-Type": "application/json"})

proc newResponse*(body: string): nimtwirp.Response =
    new(result)
    result.code = Http200
    result.body = body
    result.headers = newHttpHeaders({"Content-Type": "application/protobuf"})

proc handleHttpRequest(request: asynchttpserver.Request, handler: ServeHandlerProc) {.async.} =
    var fut = handler(request)

    yield fut

    if fut.failed:
        await respond(request, newResponse(fut.readError()))
    else:
        await respond(request, fut.read())

proc newSettings*(port = Port(8080), address = ""): Settings =
    result = Settings(
        port: port,
        address: address,
    )

proc serve*(handler: ServeHandlerProc, settings: Settings = newSettings()) =
    var
        httpServer = newAsyncHttpServer()

    proc callback(request: asynchttpserver.Request): Future[void] {.gcsafe, closure.} =
        handleHttpRequest(request, handler)

    asyncCheck httpServer.serve(settings.port, callback)

macro twirpServices*(settings: typed, x: untyped): untyped =
    expectKind(settings, nnkSym)

    var serviceHandlers = ""

    for service in x:
        let serviceName = $service
        serviceHandlers.add(&"""
    if not done:
        fut = handleRequest({serviceName}, request)
        yield fut
        if fut.failed:
            if not (fut.readError() of TwirpBadRoute):
                done = true
        else:
            done = true
""")

    var handlerProc = parseStmt(&"""
proc handler(request: asynchttpserver.Request): Future[nimtwirp.Response] {{.async.}} =
    var fut: Future[nimtwirp.Response]
    var done = false

{serviceHandlers}

    if not done:
        raise newTwirpError(TwirpBadRoute, "unknown service")
    else:
        result = fut.read()
""")

    result = newStmtList()
    add(result, handlerProc)
    add(result, parseStmt(&"nimtwirp.serve(handler, {settings.symbol})"))

proc request*(client: Client, prefix: string, meth: string, body: string): httpclient.Response =
    let address = client.address & prefix & meth
    let headers = newHttpHeaders({"Content-Length": $len(body)})
    result = request(client.client, address, httpMethod=HttpPost, body=body,
        headers=headers)
    let httpStatus = code(result)
    if httpStatus != Http200:
        if contentType(result) != "application/json":
            raise newTwirpError(TwirpInternal, "Invalid Content-Type in response")
        let errorInfo = parseJson(result.body)
        raise twirpErrorFromJson(errorInfo)
