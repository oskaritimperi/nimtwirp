import strformat
import strformat

import nimpb/compiler/compiler

proc fullName(service: Service): string =
    result = service.package
    if len(result) > 0:
        add(result, ".")
    add(result, service.name)

proc genImports(gen: ServiceGenerator): string =
    result = &"""
import asyncdispatch
import asynchttpserver
import httpclient
import json
import strutils

import {gen.fileName}

import nimtwirp/errors

"""

proc genServer(service: Service): string =
    result = &"""
type
    {service.name}* = concept x
"""

    for meth in service.methods:
        result &= &"""
        x.{meth.name}({meth.inputType}) is {meth.outputType}
"""

    result &= &"""

proc {service.name}Server*(service: {service.name}, prefix: string): auto =
    let headers = newHttpHeaders({{"Content-Type": "application/protobuf"}})
    proc cb(req: Request): Future[void] =
        try:
            let servicePrefix = prefix & "{service.fullName}/"
            if startsWith(req.url.path, servicePrefix):
                var methodName = req.url.path[len(servicePrefix)..^1]
"""

    for index, meth in service.methods:
        var ifel = "if"
        if index > 0:
            ifel = "elif"
        result &= &"""
                {ifel} methodName == "{meth.name}":
                    let inputMsg = new{meth.inputType}(req.body)
                    let outputMsg = service.{meth.name}(inputMsg)
                    let body = serialize(outputMsg)
                    result = respond(req, Http200, body, headers)
"""

    result &= &"""
                else:
                    raise newTwirpError(TwirpNotFound, "method not found")
            else:
                raise newTwirpError(TwirpNotFound, "service not found")
        except TwirpError as exc:
            let headers = newHttpHeaders({{"Content-Type": "application/json"}})
            result = req.respond(exc.httpStatus, $twirpErrorToJson(exc), headers)
        except Exception as exc:
            let headers = newHttpHeaders({{"Content-Type": "application/json"}})
            var err = newTwirpError(TwirpInternal, exc.msg)
            result = req.respond(err.httpStatus, $twirpErrorToJson(err), headers)
    result = cb

"""

proc genClient(service: Service): string =
    result = &"""


type
    {service.name}Client* = ref object
        client*: HttpClient
        address*: string

proc new{service.name}Client*(address: string): {service.name}Client =
    new(result)
    result.client = newHttpClient()
    result.client.headers = newHttpHeaders({{"Content-Type": "application/protobuf"}})
    result.address = address

"""

    for meth in service.methods:
        result &= &"""
proc {meth.name}*(client: {service.name}Client, req: {meth.inputType}): {meth.outputType} =
    let body = serialize(req)
    let resp = client.client.request(client.address & "/{service.fullName}/{meth.name}", httpMethod=HttpPost, body=body)
    let httpStatus = code(resp)
    if httpStatus != Http200:
        if contentType(resp) != "application/json":
            raise newTwirpError(TwirpInternal, "Invalid Content-Type in response")
        let errorInfo = parseJson(resp.body)
        raise twirpErrorFromJson(errorInfo)
    else:
        result = new{meth.outputType}(resp.body)

"""

proc genService(service: Service): string =
    result = genServer(service)
    result &= genClient(service)

proc newTwirpServiceGenerator*(): ServiceGenerator =
    new(result)

    let gen = result

    proc myGenImports(): string =
        result = genImports(gen)

    result.genImports = myGenImports
    result.genService = genService
    result.fileSuffix = "twirp"
