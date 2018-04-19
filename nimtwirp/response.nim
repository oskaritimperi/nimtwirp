import asyncdispatch
import asynchttpserver
import json

import nimpb/nimpb

import errors

type
    TwirpResponse* = ref object
        code*: HttpCode
        body*: string
        headers*: HttpHeaders

    TwirpErrorRef = ref TwirpError

proc respond*(req: asynchttpserver.Request, resp: TwirpResponse): Future[void] =
    req.respond(resp.code, resp.body, resp.headers)

proc newTwirpResponse*(exc: ref Exception): TwirpResponse =
    var twirpExc: TwirpErrorRef

    if exc of TwirpErrorRef:
        twirpExc = TwirpErrorRef(exc)
    else:
        twirpExc = newTwirpError(TwirpInternal, exc.msg)

    new(result)
    result.code = twirpExc.httpStatus
    result.body = $twirpErrorToJson(twirpExc)
    result.headers = newHttpHeaders({"Content-Type": "application/json"})

proc newTwirpResponse*(body: string): TwirpResponse =
    new(result)
    result.code = Http200
    result.body = body
    result.headers = newHttpHeaders({"Content-Type": "application/protobuf"})

proc newTwirpResponse*(body: JsonNode): TwirpResponse =
    new(result)
    result.code = Http200
    result.body = $body
    result.headers = newHttpHeaders({"Content-Type": "application/json"})
