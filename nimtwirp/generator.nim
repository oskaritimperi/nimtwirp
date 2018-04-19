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
import nimtwirp/response

"""

proc genServer(service: Service, prefix: string): string =
    result = &"""
const
    {service.name}Prefix* = "{prefix}{service.fullName}/"

type
    {service.name}* = ref {service.name}Obj
    {service.name}Obj* = object of RootObj
"""

    for meth in service.methods:
        result &= &"""
        {meth.name}Impl*: proc (service: {service.name}, param: {meth.inputType}): {meth.outputType}
"""

    for meth in service.methods:
        result &= &"""

proc {meth.name}*(service: {service.name}, param: {meth.inputType}): {meth.outputType} =
    if service.{meth.name}Impl == nil:
        raise newTwirpError(TwirpUnimplemented, "{meth.name} is not implemented")
    result = service.{meth.name}Impl(service, param)
"""

    result &= &"""

proc new{service.name}*(): {service.name} =
    new(result)

proc {service.name}Handler*(service: {service.name}, req: Request): TwirpResponse =
    try:
        if req.reqMethod != HttpPost:
            raise newTwirpError(TwirpBadRoute, "only POST accepted")

        if getOrDefault(req.headers, "Content-Type") != "application/protobuf":
            raise newTwirpError(TwirpInternal, "invalid Content-Type")

        if not startsWith(req.url.path, {service.name}Prefix):
            raise newTwirpError(TwirpBadRoute, "unknown service")

        let methodName = req.url.path[len({service.name}Prefix)..^1]

"""

    for index, meth in service.methods:
        var ifel = "if"
        if index > 0:
            ifel = "elif"
        result &= &"""
        {ifel} methodName == "{meth.name}":
            let inputMsg = new{meth.inputType}(req.body)
            let outputMsg = {meth.name}(service, inputMsg)
            result = newTwirpResponse(serialize(outputMsg))
"""

    result &= &"""
        else:
            raise newTwirpError(TwirpBadRoute, "unknown method")
    except Exception as exc:
        result = newTwirpResponse(exc)
"""

proc genClient(service: Service, prefix: string): string =
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
    let resp = client.client.request(client.address & {service.name}Prefix & "{meth.name}", httpMethod=HttpPost, body=body)
    let httpStatus = code(resp)
    if httpStatus != Http200:
        if contentType(resp) != "application/json":
            raise newTwirpError(TwirpInternal, "Invalid Content-Type in response")
        let errorInfo = parseJson(resp.body)
        raise twirpErrorFromJson(errorInfo)
    else:
        result = new{meth.outputType}(resp.body)

"""

proc genService(service: Service, prefix: string): string =
    result = genServer(service, prefix)
    result &= genClient(service, prefix)

proc newTwirpServiceGenerator*(prefix: string): ServiceGenerator =
    new(result)

    let gen = result

    proc myGenImports(): string =
        result = genImports(gen)

    proc myGenService(service: Service): string =
        result = genService(service, prefix)

    result.genImports = myGenImports
    result.genService = myGenService
    result.fileSuffix = "twirp"
