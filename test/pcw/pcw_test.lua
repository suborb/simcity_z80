-- The test's PCW: z88dk's PCW model (lib/ticks/memory/pcw.lua: the banks, the paging ports, the roller RAM) with the BDOS stubbed, so that the game runs on its own: BDOS 6
-- gives the keys of a script, 105 the time of day (from the cycles run), 12 the version, 9 and the console output do nothing, the rest fail.  Run it from a directory with
-- bdos.bin (the stub, bdos.asm assembled for $F606), with z88dk-ticks -b lua -lua pcw_test.lua ... -end F5F0.
--
--   PCW_SCRIPT   a file of lines "polls action": after that many polls of the keyboard since the last action, deliver the key (a character, or 0xNN) or do
--                "snap name": write screen_<name>.bin (the 32 KB of banks 1 and 2: the roller RAM is in it) and polls.txt (the cycles of every poll until then)
--   the run ends when the script is done: port $E2 says so, and the stub jumps to $F5F0

local model = (os.getenv("ZCCCFG") or (os.getenv("HOME") .. "/z88dk/lib/config")) .. "/../ticks/memory/pcw.lua"
dofile(model)
PCW.protect_base = true             -- ticks writes its own CP/M trap at address 5 of a .com: it is dropped

local polls, npolls, since, step = {}, 0, 0, 1
local script = {}

-- the base page and the BDOS stub, in the TPA's banks 4 and 7
local f = io.open("bdos.bin", "rb")
if f then
    local bytes = f:read("*a")
    f:close()
    for i = 1, #bytes do PCW.page(7)[0x3606 + i] = string.byte(bytes, i) end
end
for i, b in ipairs({ 0xc3, 0x03, 0xfc, 0, 0, 0xc3, 0x06, 0xf6 }) do PCW.page(4)[i] = b end

f = io.open(os.getenv("PCW_SCRIPT") or "script.txt", "r")
if f then
    for line in f:lines() do
        local n, what = line:match("^%s*(%d+)%s+(.-)%s*$")
        if n then script[#script + 1] = { tonumber(n), what } end
    end
    f:close()
end

local function snap(name)
    PCW.export_screen("screen_" .. name)
    local p = io.open("polls.txt", "w")
    for i = 1, #polls do p:write(polls[i], "\n") end
    p:close()
end

local function next_key()
    npolls = npolls + 1
    polls[npolls] = PCW.now()
    local ev = script[step]
    if ev == nil then return 0 end
    since = since + 1
    if since < ev[1] then return 0 end
    step = step + 1
    since = 0
    local name = ev[2]:match("^snap%s+(%S+)")
    if name then snap(name); return 0 end
    local hex = ev[2]:match("^0x(%x+)$")
    if hex then return tonumber(hex, 16) end
    return string.byte(ev[2], 1)
end

function PCW.io_in(port)
    if port == 0xe0 then return next_key() end
    if port == 0xe1 then
        local s = (PCW.now() // 4000000) % 60
        return ((s // 10) << 4) | (s % 10)
    end
    if port == 0xe2 then return step > #script and 1 or 0 end
    return nil
end
