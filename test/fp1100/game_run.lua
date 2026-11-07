-- Runs the FP-1100 game in MAME's fp1100: the game image loaded at $0000 over BASIC's RAM and started (it takes the sub-CPU over itself; MAME has no floppy pack, so the pictures are
-- written into the sub-CPU's RAM here and fp_art is patched out), for SECONDS of emulated time; the three
-- video planes are dumped to vram.bin ($2000, $6000, $A000: 8000 bytes each, as the CPU reads them: 1 = lit) at the end, and at the SNAP times (comma separated seconds) as vram_<n>.bin.
-- env: ART (art.bin), ARTRET (decimal address of _fp_art in the map: patched to ret), IMAGE (simcity.bin), SECONDS, SNAPS, KEYS ("sec:col:bit:hold_seconds,...": key matrix presses), OUT (directory)
local m = manager.machine
local main = m.devices[":maincpu"].spaces["program"]
local sub = m.devices[":sub"].spaces["program"]
local cpu = m.devices[":maincpu"]
local out = os.getenv("OUT") or "."
local seconds = tonumber(os.getenv("SECONDS") or "20")
local function load(path, addr)
  local f = assert(io.open(path, "rb")); local d = f:read("a"); f:close()
  for i = 1, #d do main:write_u8(addr + i - 1, d:byte(i)) end
  return d
end
local function dump(name)
  local f = assert(io.open(out .. "/" .. name, "wb"))
  for p = 0, 2 do for i = 0, 7999 do f:write(string.char(sub:read_u8(0x2000 + p * 0x4000 + i))) end end
  f:close()
end
local snaps = {}
for s in string.gmatch(os.getenv("SNAPS") or "", "[^,]+") do snaps[#snaps + 1] = { t = tonumber(s), done = false } end
-- key presses: KEYS="sec:col:bit:hold,..." presses matrix column col (the :KEY.col port), row bit, at sec seconds of the game for hold seconds
local keys = {}
for sec, col, bit, hold in string.gmatch(os.getenv("KEYS") or "", "([%d%.]+):(%d+):(%d+):([%d%.]+)") do
  keys[#keys + 1] = { t = tonumber(sec), col = tonumber(col), bit = tonumber(bit), hold = tonumber(hold), down = false, up = false }
end
local function key_field(col, bit)
  local port = manager.machine.ioport.ports[":KEY." .. col]
  for _, field in pairs(port.fields) do
    if field.mask == (1 << bit) then return field end
  end
  error("no key " .. col .. ":" .. bit)
end
local last_clock, last_change = -1, 0
local frames, phase, t0 = 0, 0, 0
-- the pictures straight into the sub-CPU (as fp_art sends them: 24 bytes in 32 byte slots, 345 of them from $4000/$8000, the 112 of the icons from $D000), once the takeover has put the
-- program there (the ROM program clears that memory when it starts the takeover, so it cannot be before)
local pics_done = false
local function put_pictures()
  local f = assert(io.open(os.getenv("ART"), "rb")); local art = f:read("a"); f:close()
  local de = 0x4000
  for n = 0, 456 do
    if n == 345 then de = 0xD000 end
    for k = 0, 23 do sub:write_u8(de + k, art:byte(n * 24 + k + 1)) end   -- (the debugger's write does not go through the bus: no inversion)
    de = de + 32
    if de == 0x6000 then de = 0x8000 end
  end
  pics_done = true
end
emu.register_frame_done(function()
  frames = frames + 1
  if phase == 0 and frames == 300 then
    for a = 0, 0xF7EF do main:write_u8(a, 0) end        -- (what the loader leaves: the program over a clear machine)
    local img = load(os.getenv("IMAGE"), 0)
    main:write_u8(tonumber(os.getenv("ARTRET")), 0xC9)   -- fp_art: the pictures are there already
    cpu.state["IFF1"].value = 0
    cpu.state["IFF2"].value = 0
    cpu.state["SP"].value = 0xFFF0
    cpu.state["PC"].value = 0
    t0 = emu.time()
    phase = 2
    print(string.format("game started (%d bytes) at %.3f", #img, t0))
  elseif phase == 2 then
    if not pics_done then
      local spc = m.devices[":sub"].state["PC"].value
      if spc >= 0x9000 and spc < 0x9200 then put_pictures() end
    end
    if os.getenv("TRACEPC") and frames % 7 == 0 then print(string.format("frame %d pc %04x sp %04x", frames, cpu.state["PC"].value, cpu.state["SP"].value)) end
    local t = emu.time() - t0
    for _, k in ipairs(keys) do
      if not k.down and t >= k.t then k.down = true; key_field(k.col, k.bit):set_value(1) end
      if k.down and not k.up and t >= k.t + k.hold then k.up = true; key_field(k.col, k.bit):set_value(0) end
    end
    if os.getenv("ROWS") and frames % 20 == 0 then
      local a = tonumber(os.getenv("ROWS"))
      local r = {}
      for i = 0, 11 do r[#r + 1] = string.format("%02x", main:read_u8(a + i)) end
      print(string.format("t=%.2f rows_now %s", t, table.concat(r, " ")))
    end
    if os.getenv("PCLOG") and t > tonumber(os.getenv("PCFROM") or "0") then
      pclog = pclog or assert(io.open(os.getenv("PCLOG"), "w"))
      pclog:write(string.format("%04x\n", cpu.state["PC"].value))
    end
    if os.getenv("PAUSES") then
      local a = tonumber(os.getenv("PAUSES"))
      local c = main:read_u8(a) | main:read_u8(a + 1) << 8
      if c == last_clock and frames - last_change >= 6 and os.getenv("PAUSEPC") then
        pausef = pausef or assert(io.open(os.getenv("PAUSEPC"), "w"))
        pausef:write(string.format("%d %04x %04x\n", frames - last_change, cpu.state["PC"].value, m.devices[":sub"].state["PC"].value))
      end
      local d = tonumber(os.getenv("DBG") or "0")
      local function dbg(i) return d ~= 0 and (main:read_u8(d + 2 * i) | main:read_u8(d + 2 * i + 1) << 8) or 0 end
      if c ~= last_clock then
        if frames - last_change >= 4 then print(string.format("pause: %d frames (%.0f ms) ending at t=%.2f (clock %d)  tiles %d cells %d glyphs %d since last", frames - last_change, (frames - last_change) * 16.7, t, c, dbg(0) - (dbg0 or 0), dbg(1) - (dbg1 or 0), dbg(2) - (dbg2 or 0))) end
        dbg0, dbg1, dbg2 = dbg(0), dbg(1), dbg(2)
        last_clock, last_change = c, frames
      end
    end
    if os.getenv("CLOCK") and frames % 60 == 0 then
      local a = tonumber(os.getenv("CLOCK"))
      local c = main:read_u8(a) | main:read_u8(a + 1) << 8
      print(string.format("t=%.1f clock %d", t, c))
    end
    for _, s in ipairs(snaps) do
      if not s.done and t >= s.t then s.done = true; dump(string.format("vram_%g.bin", s.t)); print(string.format("snap %g at %.3f, pc %04x", s.t, t, cpu.state["PC"].value)) end
    end
    if t >= seconds then
      dump("vram.bin")
      print(string.format("done at %.3f, main pc %04x sub pc %04x e800=%02x", t, cpu.state["PC"].value, m.devices[":sub"].state["PC"].value, sub:read_u8(0xe800)))
      m:exit()
    end
  end
end)
