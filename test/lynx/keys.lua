-- Presses keys (L_KEYS "frame:field:hold,...") and takes screenshots (L_SNAPS) without loading anything: for booting from the disk
local function split(s, sep) local t = {} for p in string.gmatch(s or "", "([^" .. sep .. "]+)") do t[#t + 1] = p end return t end
local keys, snaps = {}, {}
for _, k in ipairs(split(os.getenv("L_KEYS"), ",")) do local f, name, hold = k:match("^(%d+):(.-):(%d+)$"); keys[#keys + 1] = { tonumber(f), name, tonumber(hold) } end
for _, f in ipairs(split(os.getenv("L_SNAPS"), ",")) do snaps[tonumber(f)] = true end
local fields = {}
for tag, port in pairs(manager.machine.ioport.ports) do for name, field in pairs(port.fields) do if name ~= "" then fields[name] = fields[name] or field end end end
for _, k in ipairs(keys) do if not fields[k[2]] then print("NO FIELD " .. k[2]) end end
local last = tonumber(os.getenv("L_END"))
local cpu = manager.machine.devices[":maincpu"]
local pcf = os.getenv("L_PC") and io.open(os.getenv("L_PC"), "w")
local n = 0
emu.register_frame_done(function()
  n = n + 1
  for _, k in ipairs(keys) do
    local fld = fields[k[2]]
    if fld then if n == k[1] then fld:set_value(1) end if n == k[1] + k[3] then fld:set_value(0) end end
  end
  if pcf and n >= 900 and n % (tonumber(os.getenv("L_PCSTEP") or "20")) == 0 then pcf:write(string.format("%d %04x\n", n, cpu.state["PC"].value)) end
  if os.getenv("L_POKEVID") and n == tonumber(os.getenv("L_POKEVID")) then local io_ = cpu.spaces["io"] local m_ = cpu.spaces["program"] io_:write_u8(0x82, 0xC8) for i = 0, 255 do m_:write_u8(0x0100 + i, 0xFF) end print("poked") end
  if os.getenv("L_FDC") and n >= tonumber(os.getenv("L_FDC")) and n % 100 == 0 then local io_ = cpu.spaces["io"] print(string.format("frame %d fdc status %02x track %02x sector %02x", n, io_:read_u8(0x50), io_:read_u8(0x51), io_:read_u8(0x52))) end
  if snaps[n] then manager.machine.video:snapshot() end
  if n == last - 1 and os.getenv("L_DUMP") then local fh = io.open(os.getenv("L_DUMP"), "wb") local mem = cpu.spaces["program"] for i = 0, tonumber(os.getenv("L_DUMPLEN") or "512") - 1 do fh:write(string.char(mem:read_u8(tonumber(os.getenv("L_DUMPAT") or "CF00", 16) + i))) end fh:close() end
  if n >= last then if pcf then pcf:close() end manager.machine:exit() end
end)
