-- The FP-1100 for z88dk-ticks: the floppy pack (fdc_model.lua) and the sub-CPU, which owns the screen.  The sub-CPU is not emulated: its program (target/fp1100/sub.s.in) is modelled
-- command by command, as a coroutine that asks for the Z80's bytes the way the program's Rcv does (the handshake on ports $FF80 and $FFC0 as fp_send and fp_keys see it) and does what
-- each command does to the video RAM.  Checked only by eye against MAME's real sub-CPU (the same game screen: tiles, text, icons, panel); Ovl, Mini and Mini2 are modelled from the program but not compared.
--
-- The memory is the sub-CPU's 64 KB as the CPU reads it: a direct write of W reads back ~W (the video bus inverts), a copy (a read then a write) therefore flips, and a picture
-- stored raw is read back inverted and copied to the screen as itself.  Planes: blue $2000, red $6000, green $A000, 40x25 cells of 8 bytes; the pictures in $4000/$8000/$C000+.
--
-- env: FP_ART (art.bin: the pictures loaded straight into the sub-CPU, as fp_art would send them: 345 of them from $4000/$8000, and the icons' from $D000; not needed when the game reads them from the disc), FP_OUT (directory for the dumps, default "."),
--      FP_SNAPS (frames, comma separated: vram_<n>.bin written at the frame's Tick), FP_KEYS ("frame:col:bit:hold,...": key matrix presses, in frames),
--      FP_TICKS (what a Tick command returns: the timer overflows per frame, default 30), FP_EVERY (frames between dumps of vram.bin, default 50)
--      the disc: FDC_IMAGE etc. as fdc_model.lua.  A frame is a Tick command (the game's idle loop asks once a frame).
-- Port $00FC written with 1 dumps vram.bin at once.
local here = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
dofile(here .. "fdc_model.lua")
local fdc_in, fdc_out = io_in, io_out

local OUT = os.getenv("FP_OUT") or "."
local TICKS = tonumber(os.getenv("FP_TICKS") or "30")
local EVERY = tonumber(os.getenv("FP_EVERY") or "50")

local M = {}                                 -- the sub-CPU's memory as read
for i = 0, 65535 do M[i] = 0 end
local function rd(a) return M[a & 0xFFFF] end
local function wr(a, w) M[a & 0xFFFF] = (~w) & 0xFF end       -- a direct write
local function raw(a, x) M[a & 0xFFFF] = (~x) & 0xFF end      -- a picture byte stored as Pat would store it

-- the pictures (what fp_art sends): 24 bytes each in 32 byte slots
local art_path = os.getenv("FP_ART")
if art_path then
  local f = assert(io.open(art_path, "rb")); local d = f:read("a"); f:close()
  local de = 0x4000
  for n = 0, #d // 24 - 1 do
    if n == 345 then de = 0xD000 end
    for k = 0, 23 do raw(de + k, d:byte(n * 24 + k + 1)) end
    de = de + 32
    if de == 0x6000 then de = 0x8000 end
  end
end

-- ---- the keys ----
local keys = {}                              -- pressed: [col * 8 + bit] = true
local sched = {}
for fr, col, bit, hold in string.gmatch(os.getenv("FP_KEYS") or "", "(%d+):(%d+):(%d+):(%d+)") do
  sched[#sched + 1] = { t = tonumber(fr), col = tonumber(col), bit = tonumber(bit), hold = tonumber(hold) }
end
local frame = 0
local snaps = {}
for s in string.gmatch(os.getenv("FP_SNAPS") or "", "[^,]+") do snaps[tonumber(s)] = true end

local function dump(name)
  local f = assert(io.open(OUT .. "/" .. name, "wb"))
  local t = {}
  for p = 0, 2 do
    for i = 0, 7999 do t[#t + 1] = string.char(M[0x2000 + p * 0x4000 + i]) end
  end
  f:write(table.concat(t)); f:close()
end

-- ---- the program ----
local outq = {}
local rcv, snd
local de, v = 0, 0

local function block(src, dst)                -- BLOCK: eight bytes, read then written: the copy flips
  for k = 0, 7 do wr(dst + k, rd(src + k)) end
end

local function program()
  while true do
    local c = rcv()
    if c == 0x07 then v = rcv()                                                        -- Bank
    elseif c == 0x13 then local lo = rcv(); de = rcv() << 8 | lo                       -- Addr
    elseif c == 0x0F then for k = 0, 7 do wr(de + k, rcv()) end; de = de + 8           -- Pat
    elseif c == 0x1C then                                                              -- Cell
      for p = 0, 2 do for k = 0, 7 do wr(de + p * 0x4000 + k, rcv()) end end
      de = de + 8
    elseif c == 0x20 then                                                              -- Ovl
      for p = 0, 2 do for k = 0, 7 do local a = de + p * 0x4000 + k; wr(a, ~(rcv() | rd(a))) end end
      de = de + 8
    elseif c == 0x42 then                                                              -- Tiles
      local n = rcv() + 1
      for _ = 1, n do
        local idx = rcv()
        local hl = (((idx >> 3) + 0x40 + v) & 0xFF) << 8 | (idx & 7) << 5
        for p = 0, 2 do block(hl + p * 8, de + p * 0x4000) end
        de = de + 8
      end
    elseif c == 0x7F then                                                              -- Inv
      for p = 0, 2 do for k = 0, 7 do local a = de + p * 0x4000 + k; wr(a, rd(a)) end end
    elseif c == 0x9C then                                                              -- Fill
      local n = rcv() + 1
      rcv()
      for _ = 1, n do
        for p = 0, 2 do block(0xC400 + p * 8, de + p * 0x4000) end
        de = de + 8
      end
    elseif c == 0x9F then                                                              -- Text
      local n = rcv() + 1
      local attr = rcv()
      for _ = 1, n do
        local ch = rcv()
        local hl = 0xC000 + ch * 32
        for p = 0, 2 do
          local m = (attr >> p) & 9
          local d = de + p * 0x4000
          if m == 1 then block(hl + p * 8, d)
          elseif m == 8 then block(hl + p * 8, d); for k = 0, 7 do wr(d + k, rd(d + k)) end
          elseif m == 9 then for k = 0, 7 do wr(d + k, 0) end
          else for k = 0, 7 do wr(d + k, 0xFF) end end
        end
        de = de + 8
      end
    elseif c == 0xA2 or c == 0xA5 then                                                 -- Mini, Mini2
      for p = 0, 2 do
        local a = de + p * 0x4000
        for _ = 1, 24 do
          local w1 = rcv()
          local w2 = (c == 0xA5) and rcv() or w1
          wr(a, w1); wr(a + 1, w2)
          a = a + 8
        end
      end
      de = de + 0x8000
    elseif c == 0x96 then                                                              -- Keys: shift, the lowest column's number and row bits
      local shift = keys[8] and 1 or 0
      local col, rows = 0, 0
      for cc = 12, 2, -1 do
        local r = 0
        for b = 0, 6 do if keys[cc * 8 + b] then r = r | (1 << b) end end
        if r ~= 0 then col, rows = cc, r end
      end
      snd(shift); snd(col); snd(rows)
    elseif c == 0x99 then snd(TICKS)                                                   -- Tick
      frame = frame + 1
      for _, k in ipairs(sched) do
        local id = k.col * 8 + k.bit
        if frame == k.t then keys[id] = true end
        if frame == k.t + k.hold then keys[id] = nil end
      end
      if snaps[frame] then dump(string.format("vram_%d.bin", frame)) end
      if frame % EVERY == 0 then dump("vram.bin") end
    else
      io.stderr:write(string.format("fp_machine: unknown sub command %02x\n", c))
    end
  end
end

local co = coroutine.create(program)
rcv = function() return coroutine.yield("rcv") end
snd = function(b) outq[#outq + 1] = b; coroutine.yield("snd") end
local status
local function run(...)
  local ok, s = coroutine.resume(co, ...)
  if not ok then io.stderr:write("fp_machine: " .. tostring(s) .. "\n"); os.exit(1) end
  status = s
end
run()
local latch, phase = 0, 0

-- a dump when the process ends, if the Lua state is closed then
_G.fp_closer = setmetatable({}, { __gc = function() dump("vram.bin") end })

function io_in(addr)
  if addr == 0xFF80 then
    if phase == 1 then phase = 0; return 0 end                  -- (the acknowledgement: bit 7 clear)
    return 0x80 | ((status == "snd") and outq[1] or 0)
  end
  return fdc_in(addr)
end

function io_out(addr, value)
  value = value & 0xFF
  if addr == 0xFFC0 then latch = value; return 0 end
  if addr == 0xFF80 then
    if value == 0x20 then                                       -- INT2's pulse: a byte, or the acknowledgement of an answer
      phase = 1
      if status == "snd" then table.remove(outq, 1); run() else run(latch) end
    end
    return 0
  end
  if addr == 0x00FC then if value == 1 then dump("vram.bin") end; return 0 end
  return fdc_out(addr, value)
end
