# Package

version       = "0.1.0"
author        = "Oskari Timperi"
description   = "A new awesome nimble package"
license       = "MIT"

skipDirs = @["tests", "example"]

bin = @["nimtwirp/nimtwirp_build"]

# Dependencies

requires "nim >= 0.18.0"
requires "nimpb"
