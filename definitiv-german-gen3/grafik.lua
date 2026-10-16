-- Grafiken mit Schrift aus der DE-ROM: die Grafik-Extraktoren des Ports laufen auf der deutschen ROM.

-- DAS-ENDE-ANFANG (gen3/5_pruefung/das_ende_pruefung3.py fuehrt genau diese Funktion aus)
-- Abspann-Schlussbild wie rs/extract_credits.lua bzw. rse/credits_extract.lua: Grafik CreditsCopyrightEnd_Gfx,
-- Palette gIntroCopyright_Pal; Kachelkarte entweder aus Buchstaben (je 3x5-Karte an x, y; R/S-DE: ENDE) oder
-- fertig aus der ROM (E.karte, LZ; Smaragd-DE), uebrige Felder E.fuell (DE-Code) bzw. Kachel 1
local function dasEndeBacken(rom, E, mitText)
  local Bake = require("src.import.gba.bg_bake")
  local Lz77 = require("src.import.gba.lz77")
  local gfx = Lz77.decompress(function(i) return rom:byte(i + 1) or 0 end, E.gfx)
  local pal = {}
  for i = 1, 32 do pal[i] = rom:byte(E.pal + i) end
  pal._len = 32
  local copy = Bake.loadPalBanks(pal, 1)
  local entries, fuell = {}, E.fuell or 1
  if mitText and E.karte then
    local k = Lz77.decompress(function(i) return rom:byte(i + 1) or 0 end, E.karte)
    for i = 0, math.floor((k._len or #k) / 2) - 1 do entries[i] = k[i * 2 + 1] + k[i * 2 + 2] * 256 end
  elseif mitText then
    for _, b in ipairs(E.buchstaben) do
      for y = 0, 4 do for x = 0, 2 do
        local v = rom:byte(b[1] + y * 3 + x + 1)
        entries[(b[3] + y) * 32 + b[2] + x] = v == 255 and 1
          or v % 64 + 80 + math.floor(v / 128) % 2 * 2048 + math.floor(v / 64) % 2 * 1024
      end end
    end
  end
  local m = {}
  for i = 0, 1023 do local n = entries[i] or fuell; m[i * 2 + 1], m[i * 2 + 2] = n % 256, math.floor(n / 256) end
  m._len = 2048
  local s = Bake.bakeRegionRgba(gfx, copy, m, 240, 160, { alpha0 = true })
  local r, g, b = Bake.bgr555ToRgb8(copy[0][0])
  local bg, out = string.char(r, g, b, 255), {}
  for i = 1, #s, 4 do out[#out + 1] = s:byte(i + 3) == 0 and bg or s:sub(i, i + 3) end
  return table.concat(out)
end
-- DAS-ENDE-ENDE

return function(W)
  local mod, R, rom, log, ver = W.mod, W.R, W.rom, W.log, W.ver
  local TextIR = require("src.core.game3.scripting.text_ir")
  local CHARMAP = TextIR.CHARMAP
  local zusatzCodes, zusatzZeichen = W.zusatzCodes or {}, W.zusatzZeichen or {}
  local byte, find = string.byte, string.find

  -- Karten-Kachelsets mit Schrift (Schilder MARKT, Stockwerke ...): die Engine baekt je Kachel-Paar
  -- fertige Metatile-Bilder (native/<paar>/mids*.idx) aus der EN-ROM.  Fuer die Paare im Rezept backt
  -- der Mod sie mit den Funktionen der Engine (Tileset.loadOne, NativePack.buildLayeredIdx) aus der
  -- DE-ROM neu -- gleiche Metatile-Liste wie die EN-Datei (Kartenaufbau ist in DE gleich).  Diese Paare
  -- bereitet die Engine dann im Hauptlauf statt im Hilfsthread vor (dort gelten Mod-Huellen nicht).
  -- R/S-Abspann: Schlussbild ENDE (der Port-Extraktor kennt nur die EN-Anordnung THE END)
  pcall(function()
    local E = R.dasEnde
    if not E then return end
    local fertigBild = {}
    local function bildFuer(rel)
      local mitText = type(rel) == "string" and (rel:match("credits_rse/the_end%.rgba$") and true
        or rel:match("credits_rse/the_end_blank%.rgba$") and false)
      if mitText == nil then return nil end
      if fertigBild[mitText] == nil then
        local ok, b = pcall(dasEndeBacken, rom, E, mitText)
        if not ok then log:warn("Deutsch Gen 3: Schlussbild: %s", tostring(b)) end
        fertigBild[mitText] = ok and b or false
      end
      return fertigBild[mitText] or nil
    end
    local CacheFs = require("src.import.CacheFs")
    local vorher = CacheFs.readAt
    CacheFs.readAt = function(rel, ...)
      return bildFuer(rel) or vorher(rel, ...)
    end
  end)

  pcall(function()
    local KR = R.kacheln
    if not KR or not next(KR) then return end
    local NT = require("src.core.game3.tileset_native")
    local NativePack = require("src.import.gba.native_pack")
    local Tileset = require("src.import.gba.tileset")
    local kRom = setmetatable({ _raw = rom, data = rom, size = #rom, id = ver }, require("src.import.gba.rom"))
    local DATEI = { ["mids.idx"] = 1, ["mids_over.idx"] = 2, ["mids_mid.idx"] = 3 }
    local fertig = {}
    local function neuBacken(paar, enBlob)
      if fertig[paar] ~= nil then return fertig[paar] end
      fertig[paar] = false
      local idx = NativePack.decodeIdx(enBlob)
      local p = KR[paar]
      if not (idx and p) then return false end
      local ok, res = pcall(function()
        local a, b = Tileset.loadOne(kRom, p.primary), Tileset.loadOne(kRom, p.secondary)
        local bundle = { pairName = paar, primaryTiles = a.tiles, secondaryTiles = b.tiles,
          mapPals = Tileset.mergeMapPalettes(a.pals, b.pals), primaryMt = a.mt, secondaryMt = b.mt,
          primaryAttr = a.attr, secondaryAttr = b.attr }
        if idx.flags == NativePack.FLAG_LAYERED then
          local u, o, m = NativePack.buildLayeredIdx(bundle, idx.midIds)
          return { NativePack.encodeIdx(u), NativePack.encodeIdx(o), NativePack.encodeIdx(m) }
        end
        return { NativePack.encodeIdx(NativePack.buildIdx(bundle, idx.midIds)) }
      end)
      if not ok then log:warn("Deutsch Gen 3: Kachelset %s: %s", paar, tostring(res)) end
      fertig[paar] = ok and res or false
      return fertig[paar]
    end
    local function huelle(cache)
      if type(cache) ~= "table" then return cache end
      local h = setmetatable({}, { __index = cache })
      function h:read(rel, ...)
        local paar, datei
        if type(rel) == "string" then paar, datei = rel:match("/native/([^/]+)/([^/]+)$") end
        local nr = paar and KR[paar] and DATEI[datei]
        if nr then
          local enBlob = cache:read((rel:gsub("[^/]+$", "mids.idx")))
          local de = enBlob and neuBacken(paar, enBlob)
          if de and de[nr] then return de[nr] end
        end
        return cache:read(rel, ...)
      end
      function h:assetWorkerSpec(root, kind, key, ...)
        if kind == "pair" and KR[key] then return nil end
        return cache.assetWorkerSpec and cache:assetWorkerSpec(root, kind, key, ...) or nil
      end
      return h
    end
    local altInstall = NT.install
    NT.install = function(cache, ...)
      return altInstall(huelle(cache), ...)
    end
  end)
  -- Grafiken mit Schrift (Menue-Kopfzeilen, Typen, Knoepfe ...): der Mod bringt keine Bilder mit.
  -- Er laesst die Grafik-Extraktoren der Engine selbst auf der deutschen ROM laufen -- mit den
  -- Adressen aus dem Rezept -- und reicht deren Bilder statt der englischen weiter.  Ein Extraktor
  -- laeuft erst, wenn eines seiner Bilder zum ersten Mal geladen wird.
  local G = R.grafik
  if not G then return end
  local WURZEL = "data/generated/gba/"
  local ziel = {}
  for i, e in ipairs(G.module or {}) do
    for rel in pairs(e.dateien or {}) do
      local s = rel:find(WURZEL, 1, true)
      if s then ziel[rel:sub(s)] = i end
    end
  end
  local function relVon(pfad)
    if type(pfad) ~= "string" then return nil end
    local s = pfad:find(WURZEL, 1, true)
    local rel = s and pfad:sub(s)
    return rel and ziel[rel] and rel or nil
  end

  local K = require("src.import.gba.rse.boot_gfx")
  local Syms = require("src.import.gba.syms")
  local Versions = require("src.import.gba.versions")
  local deRom = setmetatable({ _raw = rom, data = rom, size = #rom, id = ver }, require("src.import.gba.rom"))
  local bilder, gelaufen = {}, {}

  -- Versionstabelle: Pfad "/s:NAME/n:3" -> Tabelle + Schluessel
  -- fehlt ein Zwischenglied (Tabellen, deren Schluessel ROM-Adressen sind), wird es angelegt und
  -- in `neu` vermerkt, damit es danach wieder verschwindet
  local function stelle(pfad, neu)
    local t, teile = Versions.module(), {}
    for teil in pfad:gmatch("[^/]+") do
      teile[#teile + 1] = teil:sub(1, 2) == "n:" and tonumber(teil:sub(3)) or teil:sub(3)
    end
    for i = 1, #teile - 1 do
      local k = teile[i]
      if t[k] == nil and i > 1 then
        t[k] = {}
        neu[#neu + 1] = { t, k }
      end
      t = t[k]
      if type(t) ~= "table" then return nil end
    end
    return t, teile[#teile]
  end

  local function laufe(i)
    if gelaufen[i] ~= nil then return end
    gelaufen[i] = false
    local e = G.module[i]
    local KT = G.karte or {}
    local daten, rueck, funk, funkRueck = KT.daten or {}, KT.rueck or {}, KT.funk or {}, KT.funk_rueck or {}
    -- 1) Symbole und Versionstabelle voruebergehend auf die DE-ROM stellen
    local alt = {}
    local inst = { Syms.of(ver) }
    local VS = Versions.module().SYMS
    if type(VS) == "table" and VS ~= inst[1] then inst[2] = VS end
    for _, S in ipairs(inst) do
      local a = { off = S.off, addr = S.addr, namesAt = S.namesAt, funcOff = S.funcOff, funcAt = S.funcAt, size = S.size }
      alt[S] = a
      -- R/S: Tabellen, die in der DE-Fassung mehr Eintraege haben (Rezept groessen, aus pokeruby_de.sym)
      local gr = G.groessen
      if gr and a.size then
        S.size = function(name)
          local g = gr[name] or (type(name) == "string" and gr[name:match(":(.*)$") or ""])
          if g then return g end
          return a.size(name)
        end
      end
      S.off = function(name) return daten[name] or a.off(name) end
      S.addr = function(name) return 0x08000000 + S.off(name) end
      S.namesAt = function(off)
        local t, out = rueck[off], {}
        if t then for j = 1, #t do out[j] = t[j] end end
        return out
      end
      S.funcOff = function(name) return funk[name] or a.funcOff(name) end
      S.funcAt = function(ptr)
        local off = tonumber(ptr)
        if not off then return nil end
        if off >= 0x08000000 then off = off - 0x08000000 end
        if off % 2 == 1 then off = off - 1 end
        return funkRueck[off]
      end
    end
    local altBlatt, neuTab = {}, {}
    for pfad, wert in pairs(G.blaetter or {}) do
      local t, k = stelle(pfad, neuTab)
      if t then altBlatt[#altBlatt + 1] = { t, k, t[k] }; t[k] = wert end
    end
    -- FRLG: Adressen, die fest im Code stehen (Versions.address(Basis)) -> DE
    local VM, altAdr = Versions.module(), nil
    if G.adressen and next(G.adressen) and type(VM.address) == "function" then
      altAdr = VM.address
      VM.address = function(b) return G.adressen[b] or altAdr(b) end
    end
    -- Kachelkarten, die die DE-ROM schmaler ablegt als der Extraktor liest (FRLG Teachy-TV-Endtafel "ENDE":
    -- 6x2 statt 8x2): in der Breite des Extraktors als virtuelle Tabelle hinter dem ROM-Ende bereitstellen,
    -- fehlende Spalten = Kachel 0
    local romFuer = deRom
    if e.karte16 then
      local werte, FREI = {}, 0x01F00000
      for _, k in ipairs(e.karte16) do
        local basis = FREI + #werte * 2
        for z = 0, k.hoehe - 1 do
          for s = 0, k.breite - 1 do
            local q, v = s - (k.links or 0), 0
            if q >= 0 and q < k.quelleBreite then
              local p = k.quelle + (z * k.quelleBreite + q) * 2
              v = rom:byte(p + 1) + rom:byte(p + 2) * 256
            end
            werte[#werte + 1] = v
          end
        end
        local t, key = stelle(k.blatt, neuTab)
        if t then altBlatt[#altBlatt + 1] = { t, key, t[key] }; t[key] = basis end
      end
      romFuer = setmetatable({
        u16 = function(_, off)
          if off >= FREI and off < FREI + #werte * 2 then return werte[(off - FREI) / 2 + 1] end
          return deRom:u16(off)
        end,
      }, { __index = deRom })
    end
    -- 2) Bilder vor dem PNG-Kodieren abgreifen
    local marke, nr = {}, 0
    local function merke(rec)
      nr = nr + 1
      local key = "DEUTSCH" .. nr
      marke[key] = rec
      return key
    end
    local altEnc, altGray, altMask = K.encodeIndexed, K.encodeGray, K.encodeMask
    K.encodeIndexed = function(w, h, idx, pal, tr)
      return merke({ w = w, h = h, idx = idx, pal = pal, art = tr and "png0" or "png" })
    end
    K.encodeGray = function(w, h, idx) return merke({ w = w, h = h, idx = idx, art = "gray" }) end
    K.encodeMask = function(w, h, idx, keep) return merke({ w = w, h = h, idx = idx, keep = keep, art = "mask" }) end
    local cache = {
      write = function(_, rel, bytes)
        local s = type(rel) == "string" and rel:find(WURZEL, 1, true)
        local r = s and rel:sub(s)
        if r and ziel[r] then bilder[r] = marke[bytes] or { art = "roh", bytes = bytes } end
        return true
      end,
      read = function() return nil end,
      exists = function() return false end,
    }
    local o = { game = ver }
    for k, v in pairs(e.opts or {}) do o[k] = v end
    for _, code in ipairs(zusatzCodes) do CHARMAP[code] = zusatzZeichen[code] end
    local ok, err = pcall(function() require(e.modul).run(romFuer, cache, o) end)
    for _, code in ipairs(zusatzCodes) do CHARMAP[code] = nil end
    -- Felder, deren DE-Daten anders aufgebaut sind als der Extraktor erwartet (R/S-DE: Easy-Chat-Alphabet als
    -- Zeigertabelle statt char[4][32]): Zeilen aus den DE-Zeigern des Rezepts, kodiert wie rs/extract_easy_chat_ui
    -- (styledText) und LuaWriter (quote)
    for rel, fe in pairs(G.feldErsatz or {}) do
      local rec = bilder[rel]
      if ok and rec and rec.art == "roh" and type(rec.bytes) == "string" then
        local zeilen = {}
        for i, off in ipairs(fe.offs) do
          local bytes, out = {}, {}
          for j = 0, 1023 do local b = rom:byte(off + j + 1); bytes[#bytes + 1] = b; if b == 255 then break end end
          for _, seg in ipairs(TextIR.decode(bytes, { dialect = "rs" })) do
            if seg.t == "ext" then
              out[#out + 1] = string.char(252, seg.cmd)
              for _, a in ipairs(seg.args or {}) do out[#out + 1] = string.char(a) end
            else out[#out + 1] = TextIR.toAscii({ seg }) end
          end
          local q = table.concat(out):gsub('[%z\1-\31\\"]', function(ch)
            if ch == "\\" then return "\\\\" end
            if ch == '"' then return '\\"' end
            if ch == "\n" then return "\\n" end
            if ch == "\r" then return "\\r" end
            if ch == "\t" then return "\\t" end
            return ("\\%03d"):format(ch:byte())
          end)
          zeilen[i] = '"' .. q .. '"'
        end
        local einr = rec.bytes:match("\n(%s*)" .. fe.feld .. " = {\n")
        local _, e = rec.bytes:find("\n%s*" .. fe.feld .. " = {\n")
        local ende = e and rec.bytes:find("\n" .. einr .. "},", e, true)
        if ende then
          local neu = {}
          for i, z in ipairs(zeilen) do neu[i] = einr .. "  " .. z .. "," end
          rec.bytes = rec.bytes:sub(1, e) .. table.concat(neu, "\n") .. rec.bytes:sub(ende)
        end
      end
    end
    -- 3) alles zurueck
    K.encodeIndexed, K.encodeGray, K.encodeMask = altEnc, altGray, altMask
    if altAdr then VM.address = altAdr end
    for j = #altBlatt, 1, -1 do local b = altBlatt[j]; b[1][b[2]] = b[3] end
    for j = #neuTab, 1, -1 do local b = neuTab[j]; b[1][b[2]] = nil end
    for S, a in pairs(alt) do
      S.off, S.addr, S.namesAt, S.funcOff, S.funcAt = a.off, a.addr, a.namesAt, a.funcOff, a.funcAt
      if a.size then S.size = a.size end
    end
    if not ok then log:warn("Deutsch Gen 3: Grafik %s: %s", tostring(e.modul), tostring(err)) end
    gelaufen[i] = ok
  end

  local function bild(rel)
    local i = ziel[rel]
    if not i then return nil end
    laufe(i)
    return bilder[rel]
  end
  local function rgba(rec)
    local w, h, idx = rec.w, rec.h, rec.idx
    local farbe = {}
    if rec.art == "png" or rec.art == "png0" then
      for c = 0, 255 do
        local r, g, b = K.rgb8(rec.pal and rec.pal[c] or 0)
        farbe[c] = string.char(r, g, b, (rec.art == "png0" and c == 0) and 0 or 255)
      end
    elseif rec.art == "gray" then
      for c = 0, 255 do farbe[c] = string.char(c, c, c, 255) end
    end
    local zeilen = {}
    for y = 0, h - 1 do
      local teile = {}
      for x = 1, w do
        local v = idx[y * w + x] or 0
        if rec.art == "mask" then
          teile[x] = rec.keep and rec.keep[v] and "\255\255\255\255" or "\0\0\0\0"
        else
          teile[x] = farbe[v]
        end
      end
      zeilen[y + 1] = table.concat(teile)
    end
    return table.concat(zeilen)
  end
  -- fertige PNGs (Extraktoren, die selbst ueber love.image kodieren, z. B. FRLG-Namenseingabe):
  -- 8 Bit RGB/RGBA ohne Interlace -> RGBA-Bytes (love.filesystem ist fuer Mods gesperrt)
  local function pngRgba(s)
    if type(s) ~= "string" or s:sub(2, 4) ~= "PNG" then return nil end
    local function be32(i) local a, b, c, d = s:byte(i, i + 3); return ((a * 256 + b) * 256 + c) * 256 + d end
    local pos, w, h, typ, tiefe, idat, plte, trns = 9, nil, nil, nil, nil, {}, nil, nil
    while pos + 8 <= #s do
      local len, kind = be32(pos), s:sub(pos + 4, pos + 7)
      if kind == "IHDR" then
        w, h = be32(pos + 8), be32(pos + 12)
        tiefe, typ = s:byte(pos + 16), s:byte(pos + 17)
        if s:byte(pos + 20) ~= 0 then return nil end
      elseif kind == "IDAT" then idat[#idat + 1] = s:sub(pos + 8, pos + 7 + len)
      elseif kind == "PLTE" then plte = s:sub(pos + 8, pos + 7 + len)
      elseif kind == "tRNS" then trns = s:sub(pos + 8, pos + 7 + len)
      elseif kind == "IEND" then break end
      pos = pos + 12 + len
    end
    -- Farbtyp 6 RGBA / 2 RGB mit 8 Bit; Farbtyp 3 Palette (PLTE + tRNS) mit 1, 2, 4 oder 8 Bit
    -- (z. B. Titelbild, PRESS START und Copyright aus extract_intro)
    local bpp, farbe
    if (typ == 6 or typ == 2) and tiefe == 8 then
      bpp = typ == 6 and 4 or 3
    elseif typ == 3 and plte and (tiefe == 1 or tiefe == 2 or tiefe == 4 or tiefe == 8) then
      bpp = 1
      farbe = {}
      for i = 0, #plte / 3 - 1 do
        farbe[i] = plte:sub(i * 3 + 1, i * 3 + 3) .. string.char(trns and trns:byte(i + 1) or 255)
      end
    end
    if not (w and bpp) then return nil end
    local zb = farbe and math.ceil(w * tiefe / 8) or w * bpp       -- Bytes je Zeile
    local raw = love.data.decompress("string", "zlib", table.concat(idat))
    local zeilen, prev, p = {}, {}, 1
    for x = 1, zb do prev[x] = 0 end
    local leer = string.char(0, 0, 0, 0)
    for y = 1, h do
      local f = raw:byte(p)
      local z = { raw:byte(p + 1, p + zb) }
      p = p + 1 + zb
      for x = 1, zb do
        local a = x > bpp and z[x - bpp] or 0
        local b, c = prev[x], x > bpp and prev[x - bpp] or 0
        local v = z[x] or 0
        if f == 1 then v = v + a
        elseif f == 2 then v = v + b
        elseif f == 3 then v = v + math.floor((a + b) / 2)
        elseif f == 4 then
          local q = a + b - c
          local pa, pb, pc = math.abs(q - a), math.abs(q - b), math.abs(q - c)
          v = v + ((pa <= pb and pa <= pc) and a or (pb <= pc and b or c))
        end
        z[x] = v % 256
      end
      local t = {}
      if farbe then
        local proByte = 8 / tiefe
        local maske = 2 ^ tiefe
        for x = 0, w - 1 do
          local byte = z[math.floor(x / proByte) + 1] or 0
          local schieb = (proByte - 1 - x % proByte) * tiefe
          local idx = math.floor(byte / 2 ^ schieb) % maske
          t[x + 1] = farbe[idx] or leer
        end
      else
        for x = 0, w - 1 do
          local i = x * bpp
          t[x + 1] = string.char(z[i + 1], z[i + 2], z[i + 3], bpp == 4 and z[i + 4] or 255)
        end
      end
      zeilen[y] = table.concat(t)
      prev = z
    end
    return w, h, table.concat(zeilen)
  end
  local function imageData(rel)
    local rec = bild(rel)
    if not rec then return nil end
    if rec.art == "roh" then
      if rel:sub(-4) ~= ".png" then return nil end
      if rec.data == nil then
        local ok, w, h, px = pcall(pngRgba, rec.bytes)
        rec.data = (ok and w) and love.image.newImageData(w, h, "rgba8", px) or false
      end
      return rec.data or nil
    end
    if not rec.data then
      rec.data = love.image.newImageData(rec.w, rec.h, "rgba8", rgba(rec))
    end
    return rec.data
  end

  -- R/S-Titelbild wie in der DE-Fassung (pokeruby src/title_screen.c, #elif GERMAN): DRUECKE START aus drei
  -- Sprites plus T (Animation 8) und Ue-Punkten (Animation 9), Versions-Banner (64x64) an anderer Stelle
  pcall(function()
    local T = G.rsTitel
    if not T or (ver ~= "ruby" and ver ~= "sapphire") then return end
    local Title = require("src.ui.game3.rs.title")
    local Machine = require("src.ui.game3.rse.gba_machine")
    local Sprites = require("src.core.game3.gba_sprites")
    local bit = require("bit")
    local function s16(v) v = bit.band(v, 0xFFFF); return v < 0x8000 and v or v - 0x10000 end
    local function pressCb(s)
      if s.data[0] == 1 then s.data[1] = s16(s.data[1] + 1); s.invisible = bit.band(s.data[1], 16) == 0
      else s.invisible = false end
    end
    Title.createTextBanners = function(self)
      local sp = self.m.ppu.sprites
      local template = Machine.template(self:sprite("press_start"), { paletteTag = 1001, callback = pressCb })
      local anz = #(self:sprite("press_start").anims or {})
      local function neu(anim, x, y, blinkt)
        if anim >= anz then return end
        local s = sp:get(sp:create(template, x, y, 0))
        Sprites.startAnim(s, anim)
        if blinkt then s.data[0] = 1 end
      end
      for i = 0, 2 do neu(i, T.druecke_x + i * 32, T.druecke_y, true) end
      neu(T.t_anim, T.t_x, T.druecke_y, true)
      neu(T.punkte_anim, T.punkte_x, T.punkte_y, true)
      for i = 3, 7 do neu(i, 56 + (i - 3) * 32, 148, false) end
    end
    -- Banner: beim ersten Aufruf an die DE-Stelle setzen, Zielhoehe DE
    local function banner(self, s, links)
      if not s._deutsch then
        s._deutsch = true
        s.x, s.y = T.banner_x[links and 1 or 2], T.banner_y
      end
      local d = self.m.tasks:get(s.data[1]).data
      if d[1] ~= 0 then
        s.oam.objMode, s.y, s.invisible = Sprites.OBJ_NORMAL, T.banner_ziel, false
      elseif links then
        if d[5] ~= 0 then d[5] = d[5] - 1 end
        if d[5] < 64 then
          s.invisible = false
          if s.y ~= T.banner_ziel then s.y = s.y + 1 end
          self.m.ppu:set("BLDALPHA", self:alphaReg(math.floor(d[5] / 2)))
        end
      elseif d[5] < 64 then
        s.invisible = false
        if s.y ~= T.banner_ziel then s.y = s.y + 1 end
      end
    end
    Title.bannerLeftCb = function(self, s) return banner(self, s, true) end
    Title.bannerRightCb = function(self, s) return banner(self, s, false) end
  end)

  -- Hüllen (B): Bildpfade aus dem Cache -> deutsches Bild, sonst unveraendert weiter
  pcall(function()
    local LG, LI = love.graphics, love.image
    local altImage, altData = LG.newImage, LI.newImageData
    LG.newImage = function(quelle, ...)
      local rel = relVon(quelle)
      local d = rel and imageData(rel)
      if d then return altImage(d, ...) end
      return altImage(quelle, ...)
    end
    LI.newImageData = function(quelle, ...)
      local rel = relVon(quelle)
      local d = rel and imageData(rel)
      if d then return d:clone() end
      return altData(quelle, ...)
    end
  end)
  pcall(function()
    local IndexedPng = require("src.core.game3.indexed_png")
    local altLoad = IndexedPng.load
    IndexedPng.load = function(pfad, ...)
      local rel = relVon(pfad)
      local rec = rel and bild(rel)
      if rec and (rec.art == "png" or rec.art == "png0" or rec.art == "gray") then
        local index = {}
        for j = 1, rec.w * rec.h do index[j] = rec.idx[j] or 0 end
        local plte, trns
        if rec.art ~= "gray" then
          local p = {}
          for c = 0, 255 do
            local r, g, b = K.rgb8(rec.pal and rec.pal[c] or 0)
            p[c + 1] = string.char(r, g, b)
          end
          plte = table.concat(p)
          trns = rec.art == "png0" and "\0" or nil
        end
        return { w = rec.w, h = rec.h, index = index, plte = plte, trns = trns }
      end
      return altLoad(pfad, ...)
    end
  end)
  -- Rohdaten (Kacheln, Tilemaps, RGBA), die die Bildschirme selbst zusammensetzen
  local function roh(pfad)
    local r = relVon(pfad)
    local rec = r and bild(r)
    if rec and rec.art == "roh" and type(rec.bytes) == "string" then return rec.bytes end
  end
  pcall(function()
    local CacheFs = require("src.import.CacheFs")
    local vorher = CacheFs.readAt
    CacheFs.readAt = function(rel, ...)
      local b = roh(rel)
      if b then return b end
      return vorher(rel, ...)
    end
  end)
  -- Karten-Kachelsaetze, die in der DE-ROM anders sind (Smaragd: Schilder ARENA/POKeMART, Laden, Kampfkuppel).
  -- Der Port zeichnet Karten aus vorbereiteten Metatile-Atlanten (native/<primaer>__<sekundaer>/mids*.idx).  Fuer
  -- Paare mit einem betroffenen Kachelsatz setzt der Mod diese Atlanten beim Lesen aus der DE-ROM neu zusammen
  -- -- mit denselben Port-Bausteinen wie der Import (Tileset.loadPair, NativePack.buildLayeredIdx) und denselben
  -- Metatile-Nummern wie die US-Fassung.  Diese Paare laedt der Port dann im Hauptfaden (im Hintergrund-Faden
  -- greift der Mod nicht).
  pcall(function()
    local KS = G.kachelsaetze
    if not (KS and KS.strukturen) then return end
    local CacheFs = require("src.import.CacheFs")
    local Pack = require("src.import.gba.native_pack")
    local Tileset = require("src.import.gba.tileset")
    local MapTree = require("src.import.gba.map_tree")
    local betroffen = {}
    for _, n in ipairs(KS.betroffen or {}) do betroffen[n] = true end
    local function paarBetroffen(paar)
      local a, b = tostring(paar):match("^(.-)__(.+)$")
      return a and (betroffen[a] or betroffen[b]) and KS.strukturen[a] and KS.strukturen[b] and a, b
    end
    local function spec(name)
      local ts = MapTree.parseTileset(deRom, 0x08000000 + KS.strukturen[name])
      local function off(p) return p and p >= 0x08000000 and p - 0x08000000 or nil end
      return {
        compressed = ts.compressed, secondary = ts.secondary, tiles = off(ts.tilesPtr),
        palettes = off(ts.palettesPtr), metatiles = off(ts.metatilesPtr), attributes = off(ts.attributesPtr),
        metatile_bytes = ts.metatile_bytes, attr_bytes = ts.attr_bytes, palette_count = ts.palette_count or 16,
      }
    end
    local fertig = {}
    local vorher = CacheFs.readAt
    local function neuBauen(prefix, paar)
      if fertig[paar] == nil then
        fertig[paar] = false
        local ok, err = pcall(function()
          local a, b = paarBetroffen(paar)
          local alt = vorher(prefix .. "native/" .. paar .. "/mids.idx")
          local idx = alt and Pack.decodeIdx(alt)
          if not idx then return end
          local bundle = assert(Tileset.loadPair(deRom,
            { tilesets = { [a] = spec(a), [b] = spec(b) }, tileset_pairs = { [paar] = { primary = a, secondary = b } } },
            paar))
          local unter, ueber, mitte = Pack.buildLayeredIdx(bundle, idx.midIds)
          fertig[paar] = {
            ["mids.idx"] = Pack.encodeIdx(unter), ["mids_over.idx"] = Pack.encodeIdx(ueber),
            ["mids_mid.idx"] = Pack.encodeIdx(mitte), ["palettes.bin"] = Pack.encodePalettes(bundle.mapPals),
          }
        end)
        if not ok then log:warn("Deutsch Gen 3: Kachelsatz %s: %s", tostring(paar), tostring(err)) end
      end
      return fertig[paar] or nil
    end
    CacheFs.readAt = function(rel, ...)
      if type(rel) == "string" then
        local prefix, paar, datei = rel:match("^(.-)native/([%w_]+)/([%w_]+%.%w+)$")
        if paar and paarBetroffen(paar) then
          local t = neuBauen(prefix, paar)
          if t and t[datei] then return t[datei] end
        end
      end
      return vorher(rel, ...)
    end
    -- betroffene Paare nicht an den Hintergrund-Faden geben (assetWorkerSpec = nil -> Laden im Hauptfaden)
    local Stream = require("src.core.game3.asset_stream")
    local altNew = Stream.new
    Stream.new = function(kind, cache, ...)
      if kind == "pair" and type(cache) == "table" and cache.assetWorkerSpec then
        local spec0 = cache.assetWorkerSpec
        cache.assetWorkerSpec = function(self, root, k, key, ...)
          if k == "pair" and paarBetroffen(key) then return nil end
          return spec0(self, root, k, key, ...)
        end
      end
      return altNew(kind, cache, ...)
    end
  end)
  -- Lua-Manifeste aus dem DE-Lauf (Tabellen), einmal geladen
  local fertigLua = {}
  local function deLua(pfad)
    local r = relVon(pfad)
    if not (r and r:sub(-4) == ".lua") then return nil end
    if fertigLua[r] == nil then
      local b = roh(r)
      local chunk = b and (loadstring or load)(b, "@" .. r)
      if chunk and setfenv then setfenv(chunk, {}) end
      local ok, tab = false, nil
      if chunk then ok, tab = pcall(chunk) end
      fertigLua[r] = (ok and type(tab) == "table") and tab or false
      -- einzelne Felder, die der Extraktor nach der EN-Fassung festlegt (Rezept manifestFelder)
      local felder = fertigLua[r] and G.manifestFelder and G.manifestFelder[r]
      if felder then for k, v in pairs(felder) do fertigLua[r][k] = v end end
    end
    return fertigLua[r] or nil
  end
  pcall(function()
    local Kit = require("src.ui.game3.rse.scene_kit")
    local vorher = Kit.loadLua
    Kit.loadLua = function(pfad, ...)
      return deLua(pfad) or vorher(pfad, ...)
    end
  end)
  -- GBA-Bildschirme (Titel, Intro ...): Machine:manifest laedt mit love.filesystem.load (fuer Mods gesperrt)
  pcall(function()
    local Machine = require("src.ui.game3.rse.gba_machine")
    local vorher = Machine.manifest
    Machine.manifest = function(self, pfad, ...)
      local m = self.manifests and self.manifests[pfad]
      if m then return m end
      local t = deLua(pfad)
      if t then
        if self.manifests then self.manifests[pfad] = t end
        return t
      end
      return vorher(self, pfad, ...)
    end
  end)
  -- RS-Team-Menue: die Knoepfe ZURUECK/OK sind Kacheln aus misc.gfx, die party_chrome direkt mit
  -- love.filesystem.read liest (fuer Mods gesperrt) -> Knopf wie die Engine zeichnen, Kacheln aus DE
  pcall(function()
    if ver ~= "ruby" and ver ~= "sapphire" then return end
    local PC = require("src.ui.game3.rs.party_chrome")
    local Kit = require("src.ui.game3.rse.scene_kit")
    local kacheln = {}
    local function kachel(m, src, id, bank)
      local key = id .. ":" .. bank
      if not kacheln[key] then
        local data = love.image.newImageData(8, 8)
        for py = 0, 7 do for px = 0, 7 do
          local b = src:byte(id * 32 + py * 4 + math.floor(px / 2) + 1) or 0
          local index = math.floor(b / 16 ^ (px % 2)) % 16
          local r, g, bl = Kit.rgb555(m.palettes.bg[bank * 16 + index + 1])
          data:setPixel(px, py, r, g, bl, index == 0 and 0 or 1)
        end end
        local img = love.graphics.newImage(data)
        img:setFilter("nearest", "nearest")
        kacheln[key] = img
      end
      return kacheln[key]
    end
    local function knopf(kind, selected)
      local m = PC._man or PC.manifest()
      local row = m and m.buttons and m.buttons[kind]
      local src = m and roh(m.gfx)
      if not (row and src) then return false end
      love.graphics.setColor(1, 1, 1, 1)
      for i, id in ipairs(row.tiles) do
        love.graphics.draw(kachel(m, src, id, selected and 2 or 1),
          (row.x + (i - 1) % 6) * 8, (row.y + math.floor((i - 1) / 6)) * 8 + 1)
      end
      return true
    end
    local altCancel, altConfirm = PC.drawCancelButton, PC.drawConfirmButton
    PC.drawCancelButton = function(a, b, selected, ...)
      if not knopf("cancel", selected) then return altCancel(a, b, selected, ...) end
    end
    PC.drawConfirmButton = function(a, b, selected, ...)
      if not knopf("confirm", selected) then return altConfirm(a, b, selected, ...) end
    end
  end)
  pcall(function()
    local CacheBlob = require("src.import.CacheBlob")
    local vorher = CacheBlob.readFs
    CacheBlob.readFs = function(rel, ...)
      local b = roh(rel)
      if b then return b end
      return vorher(rel, ...)
    end
  end)
end
