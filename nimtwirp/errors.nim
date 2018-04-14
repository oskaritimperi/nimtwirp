import json
import httpcore

type
    TwirpError* = object of Exception
        code*: string
        httpStatus*: HttpCode

    TwirpCanceled* = object of TwirpError
    TwirpUnknown* = object of TwirpError
    TwirpInvalidArgument* = object of TwirpError
    TwirpDeadlineExceeded* = object of TwirpError
    TwirpNotFound* = object of TwirpError
    TwirpBadRoute* = object of TwirpError
    TwirpAlreadyExists* = object of TwirpError
    TwirpPermissionDenied* = object of TwirpError
    TwirpUnauthenticated* = object of TwirpError
    TwirpResourceExhausted* = object of TwirpError
    TwirpFailedPrecondition* = object of TwirpError
    TwirpAborted* = object of TwirpError
    TwirpOutOfRange* = object of TwirpError
    TwirpUnimplemented* = object of TwirpError
    TwirpInternal* = object of TwirpError
    TwirpUnavailable* = object of TwirpError
    TwirpDataloss* = object of TwirpError

template setErrorInfo(error: ref TwirpError, cod: string, httpStatu: HttpCode) =
    error.code = cod
    error.httpStatus = httpStatu

template newTwirpError*(T: typedesc, msg: string): untyped =
    var err = newException(T, msg)
    when T is TwirpCanceled: setErrorInfo(err, "canceled", Http408)
    elif T is TwirpUnknown: setErrorInfo(err, "unknown", Http500)
    elif T is TwirpInvalidArgument: setErrorInfo(err, "invalid_argument", Http400)
    elif T is TwirpDeadlineExceeded: setErrorInfo(err, "deadline_exceeded", Http408)
    elif T is TwirpNotFound: setErrorInfo(err, "not_found", Http404)
    elif T is TwirpBadRoute: setErrorInfo(err, "bad_route", Http404)
    elif T is TwirpAlreadyExists: setErrorInfo(err, "already_exists", Http409)
    elif T is TwirpPermissionDenied: setErrorInfo(err, "permission_denied", Http403)
    elif T is TwirpUnauthenticated: setErrorInfo(err, "unauthenticated", Http401)
    elif T is TwirpResourceExhausted: setErrorInfo(err, "resource_exhausted", Http403)
    elif T is TwirpFailedPrecondition: setErrorInfo(err, "failed_precondition", Http412)
    elif T is TwirpAborted: setErrorInfo(err, "aborted", Http409)
    elif T is TwirpOutOfRange: setErrorInfo(err, "out_of_range", Http400)
    elif T is TwirpUnimplemented: setErrorInfo(err, "unimplemented", Http501)
    elif T is TwirpInternal: setErrorInfo(err, "internal", Http500)
    elif T is TwirpUnavailable: setErrorInfo(err, "unavailable", Http503)
    elif T is TwirpDataloss: setErrorInfo(err, "dataloss", Http500)
    else:
        {.fatal:"unknown twirp error".}
    err

proc twirpErrorToJson*[T](error: T): JsonNode =
    %*{
        "code": error.code,
        "msg": error.msg
    }

proc twirpErrorFromJson*(node: JsonNode): ref TwirpError =
    if node.kind != JObject:
        raise newException(ValueError, "object expected")

    let code = node["code"].str
    let msg = node["msg"].str

    case code
    of "canceled": result = newTwirpError(TwirpCanceled, msg)
    of "unknown": result = newTwirpError(TwirpUnknown, msg)
    of "invalid_argument": result = newTwirpError(TwirpInvalidArgument, msg)
    of "deadline_exceeded": result = newTwirpError(TwirpDeadlineExceeded, msg)
    of "not_found": result = newTwirpError(TwirpNotFound, msg)
    of "bad_route": result = newTwirpError(TwirpBadRoute, msg)
    of "already_exists": result = newTwirpError(TwirpAlreadyExists, msg)
    of "permission_denied": result = newTwirpError(TwirpPermissionDenied, msg)
    of "unauthenticated": result = newTwirpError(TwirpUnauthenticated, msg)
    of "resource_exhausted": result = newTwirpError(TwirpResourceExhausted, msg)
    of "failed_precondition": result = newTwirpError(TwirpFailedPrecondition, msg)
    of "aborted": result = newTwirpError(TwirpAborted, msg)
    of "out_of_range": result = newTwirpError(TwirpOutOfRange, msg)
    of "unimplemented": result = newTwirpError(TwirpUnimplemented, msg)
    of "internal": result = newTwirpError(TwirpInternal, msg)
    of "unavailable": result = newTwirpError(TwirpUnavailable, msg)
    of "dataloss": result = newTwirpError(TwirpDataloss, msg)
    else: raise newException(ValueError, "Invalid twirp error code in response")
