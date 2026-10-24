-- Syntax check a Luau file without Studio: lune run parse_check.luau <file.luau>
local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")
local path = process.args[1]
local ok, err = pcall(luau.compile, fs.readFile(path))
print(if ok then "PARSE_OK " .. path else "PARSE_FAIL " .. tostring(err))
