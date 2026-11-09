-- Boots the Lynx 128K to BASIC, then loads a binary into the user RAM (port $82 = $08: writes go to bank 1) and starts it:
--   L_BIN file, L_ORG hex load address, L_START hex entry, L_ISR hex address of an interrupt handler for $0038, L_AT frame to inject,
--   L_SNAPS frames to screenshot, L_END frame to stop; L_KEYS "frame:field:hold,..." presses keys (field names as the Lynx's keys)
local function split(s, sep) local t = {} for p in string.gmatch(s or "", "([^" .. sep .. "]+)") do t[#t + 1] = p end return t end
local cpu = manager.machine.devices[":maincpu"]
local mem, ios = cpu.spaces["program"], cpu.spaces["io"]
local fh = assert(io.open(os.getenv("L_BIN"), "rb"))
local bin = fh:read("a")
fh:close()
local org, start, isr = tonumber(os.getenv("L_ORG"), 16), tonumber(os.getenv("L_START"), 16), tonumber(os.getenv("L_ISR") or "0", 16)
local at, last = tonumber(os.getenv("L_AT") or "300"), tonumber(os.getenv("L_END") or "600")
local snaps, keys = {}, {}
for _, f in ipairs(split(os.getenv("L_SNAPS"), ",")) do snaps[tonumber(f)] = true end
for _, k in ipairs(split(os.getenv("L_KEYS"), ",")) do local f, name, hold = k:match("^(%d+):(.-):(%d+)$"); keys[#keys + 1] = { tonumber(f), name, tonumber(hold) } end
local fields = {}
for tag, port in pairs(manager.machine.ioport.ports) do for name, field in pairs(port.fields) do if name ~= "" then fields[name] = fields[name] or field end end end
local peeks = {}
for _, p in ipairs(split(os.getenv("L_PEEK"), ",")) do local f, a = p:match("^(%d+):(%x+)$"); peeks[#peeks + 1] = { tonumber(f), tonumber(a, 16) } end
local dumps = {}
for _, d in ipairs(split(os.getenv("L_DUMPS"), ",")) do local f, a, l, file = d:match("^(%d+):(%x+):(%d+):(.+)$"); dumps[#dumps + 1] = { tonumber(f), tonumber(a, 16), tonumber(l), file } end
local pokes = {}
for _, p in ipairs(split(os.getenv("L_POKE"), ",")) do local f, a, v = p:match("^(%d+):(%x+):(%x+)$"); pokes[#pokes + 1] = { tonumber(f), tonumber(a, 16), tonumber(v, 16) } end
local n = 0
emu.register_frame_done(function()
  n = n + 1
  if n == at then
    local art = os.getenv("L_ART")
    if art then                                      -- the art image into the alternate green plane (CPU $C000-$FFFF with the video writes on and the RAM writes off)
      local af = assert(io.open(art, "rb"))
      local ab = af:read("a")
      af:close()
      ios:write_u8(0x82, 0xC8)
      for i = 1, #ab do mem:write_u8(0xC000 + i - 1, ab:byte(i)) end
    end
    ios:write_u8(0x82, 0x08)                       -- writes to the user RAM only, reads from it
    for i = 1, #bin do mem:write_u8(org + i - 1, bin:byte(i)) end
    if isr ~= 0 then mem:write_u8(0x38, 0xC3) mem:write_u8(0x39, isr & 255) mem:write_u8(0x3A, isr >> 8) end   -- (a program with its own vectors sets L_ISR to 0)
    cpu.state["SP"].value = tonumber(os.getenv("L_SP") or "FFF0", 16)
    cpu.state["PC"].value = start
    print("injected " .. #bin .. " bytes at " .. string.format("%04x", org))
  end
  for _, k in ipairs(keys) do
    local fld = fields[k[2]]
    if fld then if n == k[1] then fld:set_value(1) end if n == k[1] + k[3] then fld:set_value(0) end end
  end
  for _, d in ipairs(dumps) do if n == d[1] then local fh = io.open(d[4], "wb") for i = 0, d[3] - 1 do fh:write(string.char(mem:read_u8(d[2] + i))) end fh:close() end end
  for _, p in ipairs(pokes) do if n == p[1] then mem:write_u8(p[2], p[3]) end end
  for _, p in ipairs(peeks) do if n == p[1] then print(string.format("peek frame %d %04x = %02x", n, p[2], mem:read_u8(p[2]))) end end
  if snaps[n] then manager.machine.video:snapshot() end
  if n >= last then manager.machine:exit() end
end)
