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

import nimtwirp/nimtwirp
import nimtwirp/errors

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
        {meth.name}Impl*: proc (service: {service.name}, param: {meth.inputType}): Future[{meth.outputType}] {{.gcsafe, closure.}}
"""

    for meth in service.methods:
        result &= &"""

proc {meth.name}*(service: {service.name}, param: {meth.inputType}): Future[{meth.outputType}] {{.async.}} =
    if service.{meth.name}Impl == nil:
        raise newTwirpError(TwirpUnimplemented, "{meth.name} is not implemented")
    result = await service.{meth.name}Impl(service, param)
"""

    result &= &"""

proc new{service.name}*(): {service.name} =
    new(result)

proc handleRequest*(service: {service.name}, req: Request): Future[nimtwirp.Response] {{.async.}} =
    let (contentType, methodName) = validateRequest(req, {service.name}Prefix)

"""

    for index, meth in service.methods:
        var ifel = "if"
        if index > 0:
            ifel = "elif"
        result &= &"""
    {ifel} methodName == "{meth.name}":
        var inputMsg: {meth.inputType}

        if contentType == "application/protobuf":
            inputMsg = new{meth.inputType}(req.body)
        elif contentType == "application/json":
            let node = parseJson(req.body)
            inputMsg = parse{meth.inputType}(node)

        let outputMsg = await {meth.name}(service, inputMsg)

        if contentType == "application/protobuf":
            return nimtwirp.newResponse(serialize(outputMsg))
        elif contentType == "application/json":
            return nimtwirp.newResponse(toJson(outputMsg))
"""

    result &= &"""
    else:
        raise newTwirpError(TwirpBadRoute, "unknown method")
"""

proc genClient(service: Service, prefix: string): string =
    result = &"""


type
    {service.name}Client* = ref object of nimtwirp.Client

proc new{service.name}Client*(address: string, kind = ClientKind.Protobuf): {service.name}Client =
    new(result)
    result.client = newHttpClient()
    result.kind = kind
    case kind
    of ClientKind.Protobuf:
        result.client.headers = newHttpHeaders({{"Content-Type": "application/protobuf"}})
    of ClientKind.Json:
        result.client.headers = newHttpHeaders({{"Content-Type": "application/json"}})
    result.address = address

"""

    for meth in service.methods:
        result &= &"""
proc {meth.name}*(client: {service.name}Client, req: {meth.inputType}): {meth.outputType} =
    var body: string
    case client.kind
    of ClientKind.Protobuf:
        body = serialize(req)
    of ClientKind.Json:
        body = $toJson(req)
    let resp = request(client, {service.name}Prefix, "{meth.name}", body)
    case client.kind
    of ClientKind.Protobuf:
        result = new{meth.outputType}(resp.body)
    of ClientKind.Json:
        result = parse{meth.outputType}(parseJson(resp.body))

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
