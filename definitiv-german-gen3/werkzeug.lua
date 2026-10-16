-- Gemeinsame Helfer aller Bausteine.  Gibt W zurueck (oder nil, wenn die deutsche ROM fehlt).
--   W.R                Rezept (alle Bausteine zusammen, vor dem ersten Baustein geladen)
--   W.decodeAt(off, b) Text-IR ab einer DE-Adresse bis $FF (wie read_text_ir des Ports; b = Kampftext)
--   W.klartext(off)    Klartext ab einer DE-Adresse (Namen)
--   W.stueck(off, len) Klartext eines Stuecks (Absatz = \f, Folgezeile = \v)
--   W.teile(liste)     Rezeptteile (Text oder {Adresse, Laenge}) -> Klartext
--   W.zusatzCodes/-Zeichen  deutsche Zusatzzeichen (fuer die Grafik-Extraktoren)
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local log = mod.log
  local ver = GameVersion.get()
  -- Regel: jede Edition holt alles nur aus ihrem deutschen Gegenstueck
  local IMPORT = { ruby = "rubin_de", sapphire = "saphir_de", emerald = "smaragd_de",
                   firered = "feuerrot_de", leafgreen = "blattgruen_de" }
  local importId = IMPORT[ver]
  if not importId then
    log:warn("Deutsch Gen 3: unbekannte Edition %s", tostring(ver))
    return nil
  end
  local info, ierr = mod.imports:info(importId)
  if not info then
    log:warn("Deutsch Gen 3: deutsche ROM fuer %s fehlt (%s)", ver, tostring(ierr))
    return nil
  end
  local chunks, pos = {}, 0
  while pos < info.size do
    local n = math.min(4 * 1024 * 1024, info.size - pos)
    local part, rerr = mod.imports:read(importId, pos, n)
    if not part then
      log:warn("Deutsch Gen 3: ROM nicht lesbar: %s", tostring(rerr))
      return nil
    end
    chunks[#chunks + 1] = part
    pos = pos + #part
    if #part == 0 then break end
  end
  local rom = table.concat(chunks)
  chunks = nil

  local W = { mod = mod, log = log, ver = ver, rom = rom, R = {} }
  -- ------------------------------------------------------------ alle Rezepte zuerst
  for _, baustein in ipairs({ "dialoge", "daten", "port_texte", "layout", "grafik" }) do
    local name = "rezept_" .. ver .. "_" .. baustein .. ".lua"
    local src = mod:read(name)
    if src then
      local chunk, cerr = (loadstring or load)(src, "@" .. name)
      if not chunk then
        log:warn("Deutsch Gen 3: Rezept fehlerhaft (%s): %s", name, tostring(cerr))
        return nil
      end
      for k, v in pairs(chunk() or {}) do W.R[k] = v end
    end
  end
  local R = W.R

  -- ------------------------------------------------------------ Dekodieren (Decoder des Ports)
  local TextIR = require("src.core.game3.scripting.text_ir")
  local byte, find = string.byte, string.find
  -- wie src/import/gba/extract_scripts.lua text_opts(battle)
  local dialect = TextIR.dialectOf(ver)
  local function opts(battle)
    if dialect == TextIR.DEFAULT_DIALECT then
      return battle and { battle = true } or nil
    end
    return { battle = battle or nil, dialect = dialect }
  end
  local plain, battleOpts = opts(false), opts(true)

  -- Die Decode-Tabelle des Ports (TextIR.CHARMAP) kennt nur die Zeichen der US-ROM; Unbekanntes wird "?".
  -- Die deutschen ROMs nutzen Ae Oe Ue ae oe ue ss (und weitere Latin-Zeichen derselben Schrift).  Nur fuer
  -- die Dauer jedes eigenen Dekodierens werden die Zeichen ergaenzt, die die Gen-3-Schrift zeichnen kann
  -- (FrlgFont.LATIN_GLYPHS); danach ist die Tabelle wieder wie vorher.
  local CHARMAP = TextIR.CHARMAP
  W.zusatzCodes, W.zusatzZeichen = {}, {}
  pcall(function()
    for code, ch in pairs(require("src.ui.game3.frlg_font").LATIN_GLYPHS or {}) do
      if CHARMAP[code] == nil then
        W.zusatzCodes[#W.zusatzCodes + 1] = code
        W.zusatzZeichen[code] = ch
      end
    end
  end)
  local function mitZeichen(fn, ...)
    for _, code in ipairs(W.zusatzCodes) do CHARMAP[code] = W.zusatzZeichen[code] end
    local ok, a = pcall(fn, ...)
    for _, code in ipairs(W.zusatzCodes) do CHARMAP[code] = nil end
    if not ok then error(a, 0) end
    return a
  end
  W.mitZeichen = mitZeichen

  W.decodeAt = function(off, battle)
    local stop = find(rom, "\255", off + 1, true)
    if not stop then return nil end
    local bytes = { byte(rom, off + 1, stop) }
    return mitZeichen(TextIR.decode, bytes, battle and battleOpts or plain)
  end
  W.decodeBytes = function(bytes)
    return mitZeichen(TextIR.decode, bytes, plain)
  end
  W.klartext = function(off)
    local ir = W.decodeAt(off, false)
    if not ir then return nil end
    local s = {}
    for _, seg in ipairs(ir) do
      if seg.t == "text" then s[#s + 1] = seg.s
      elseif seg.t == "nl" or seg.t == "para" or seg.t == "scroll" then s[#s + 1] = "\n"
      elseif seg.t == "tag" and seg.tag then s[#s + 1] = seg.tag end
    end
    return table.concat(s)
  end
  W.stueck = function(off, len)
    local bytes = { byte(rom, off + 1, off + len) }
    bytes[#bytes + 1] = 0xFF
    local s = {}
    for _, seg in ipairs(mitZeichen(TextIR.decode, bytes, opts(false)) or {}) do
      if seg.t == "text" then s[#s + 1] = seg.s
      elseif seg.t == "nl" then s[#s + 1] = "\n"
      elseif seg.t == "para" then s[#s + 1] = "\f"
      elseif seg.t == "scroll" then s[#s + 1] = "\v"
      elseif seg.t == "tag" and seg.tag then s[#s + 1] = seg.tag end
    end
    return table.concat(s)
  end
  W.teile = function(liste)
    local out = {}
    for _, t in ipairs(liste) do out[#out + 1] = type(t) == "string" and t or W.stueck(t[1], t[2]) end
    return table.concat(out)
  end

  -- ------------------------------------------------------------ Bausteine
  -- ------------------------------------------------------------ Pruefsummen statt Spieltext
  -- Der Mod enthaelt keine englischen Spieltexte, auch nicht als Suchschluessel.  Rezepte und Kataloge
  -- fuehren Texte des Ports als Pruefsumme "~" .. FNV-1a-32 (8 Hex) .. Laenge (4 Hex); hier wird die
  -- Pruefsumme des englischen Port-Texts zur Laufzeit gebildet.  Gegenstueck fuer die Werkzeuge:
  -- Test/werkzeug/pruefsumme.py (muss dieselben Werte liefern).
  local bxor, sbyte, sformat = bit.bxor, string.byte, string.format
  local summen = {}
  W.pruefsumme = function(s)
    local h = summen[s]
    if h then return h end
    local x = 2166136261
    for i = 1, #s do
      x = bxor(x, sbyte(s, i)) % 4294967296
      x = (x * 403 + (x % 256) * 16777216) % 4294967296
    end
    h = sformat("~%08x%04x", x, #s % 65536)
    summen[s] = h
    return h
  end
  -- tab[text] ueber die Pruefsumme (Klartext-Schluessel bleiben moeglich: Port-Bezeichner, Labels)
  W.nachText = function(tab, s)
    if type(tab) ~= "table" or type(s) ~= "string" then return nil end
    local v = tab[s]
    if v == nil then v = tab[W.pruefsumme(s)] end
    return v
  end
  -- Uebersetzungs-Katalog des Ports (src/core/Strings.lua liest catalog[quelle]) und data.text: Eintraege
  -- stehen unter der Pruefsumme; ein __index findet sie ueber den englischen Text (auch "kontext|quelle").
  W.katalogMitPruefsummen = function()
    pcall(function()
      local Strings = require("src.core.Strings")
      if Strings._deutschLoad then return end
      Strings._deutschLoad = Strings.load
      -- data.strings (Katalog) und data.text (Gen 1: Klartext-Saetze der Port-Skripte, show_text sucht sie
      -- dort) bekommen denselben Pruefsummen-Zugriff; beide sind nach dem Zusammenfuehren der Mods fertig
      local function mitPruefsummen(t)
        if type(t) ~= "table" or getmetatable(t) then return end
        -- Treffer werden in einer eigenen Tabelle gemerkt, nicht in t (der Port durchlaeuft t mit pairs)
        local fehlt, gefunden = {}, {}
        setmetatable(t, { __index = function(tab, k)
          if type(k) ~= "string" or fehlt[k] or k:sub(1, 1) == "~" then return nil end
          local v = gefunden[k]
          if v ~= nil then return v end
          v = rawget(tab, W.pruefsumme(k))
          if v == nil then fehlt[k] = true else gefunden[k] = v end
          return v
        end })
      end
      Strings.load = function(data, ...)
        if type(data) == "table" then
          mitPruefsummen(data.strings)
          mitPruefsummen(data.text)
        end
        return Strings._deutschLoad(data, ...)
      end
    end)
  end
  W.katalogMitPruefsummen()

  W.baustein = function(name)
    local src = mod:read(name .. ".lua")
    local fn, err = (loadstring or load)(src or "", "@" .. name .. ".lua")
    if not fn then
      log:warn("Deutsch Gen 3: %s fehlerhaft: %s", name, tostring(err))
      return
    end
    local ok, e = pcall(function()
      local f = fn()
      if name == "layout" then
        -- layout.lua gibt install(ctx) zurueck; ctx = { mod, R (Rezept), ver, log, rom (DE-ROM-Bytes) }
        f({ mod = mod, R = R, ver = ver, log = log, rom = rom })
      else
        f(W)
      end
    end)
    if not ok then log:warn("Deutsch Gen 3: %s: %s", name, tostring(e)) end
  end

  return W
end
