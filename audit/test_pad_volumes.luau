-- Compatibility entrypoint: execute current production modules, not stale audit/PadTouchService.luau.
local fs = require('@lune/fs')
local luau = require('@lune/luau')
luau.load(fs.readFile('audit/test_pad_claim_contract.luau'))()
