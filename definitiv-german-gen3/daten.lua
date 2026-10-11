-- Namen und Daten aus der DE-ROM:
--   * Pokemon-, Attacken-, Faehigkeiten- und Itemnamen (+ Itembeschreibungen): nur die Anzeige ist deutsch,
--     die internen Namenstabellen des Ports bleiben englisch (daraus baut er Schluessel wie Pokemon.keyName)
--   * Datendateien mit Anzeigetext, die der Port direkt liest (Beschreibungen, Wettbewerb, Beeren, Pokedex):
--     beim Lesen werden die englischen Texte durch die deutschen ersetzt (R.daten: EN-Text -> DE-Teile)
--   * Datendateien mit eingebettetem Text je Eintrag (Kampfzone, Lehrling, Pyramide, Trainerhuegel:
--     { ir, key = "g3:...", name }): das eingebettete englische ir wird durch das DE-ir ersetzt (R.irDateien)
--   * Fundort im Trainer-Memo (der Ort steht als englischer Text im Spielstand)
return function(W)
  local mod, R, log = W.mod, W.R, W.log

  -- ------------------------------------------------------------ Namen
  local N = R.names or {}
  local DE = { species = {}, moves = {}, abilities = {}, items = {} }
  for feld, tab in pairs({ species = N.species, moves = N.moves, abilities = N.abilities }) do
    for i, off in pairs(tab or {}) do DE[feld][tonumber(i)] = W.klartext(off) end
  end
  for i, e in pairs(N.items or {}) do
    DE.items[tonumber(i)] = { name = W.klartext(e[1]), description = e[2] ~= 0 and W.klartext(e[2]) or nil }
  end
  pcall(function()
    local P = require("src.core.game3.pokemon")
    P._deutschName = P._deutschName or P.name
    P.name = function(species, ...)
      local n = DE.species[tonumber(species) or -1]
      if n and n ~= "" then return n end
      return P._deutschName(species, ...)
    end
    -- Attacken/Faehigkeiten: der Port nimmt viele Eingabeformen an; der EN-Name, den er liefert, wird ueber
    -- dieselbe Indexnummer der ROM-Tabelle auf den DE-Namen abgebildet.
    local function karte(enTab, deTab)
      local m = {}
      for i, en in pairs(enTab or {}) do
        if type(en) == "string" and deTab[i] then m[en] = deTab[i] end
      end
      return m
    end
    local mvKarte, abKarte
    P._deutschMoveName = P._deutschMoveName or P.moveName
    P.moveName = function(...)
      local en = P._deutschMoveName(...)
      if not mvKarte then
        if not P._moveNames then return en end
        mvKarte = karte(P._romMoveNames or P._moveNames, DE.moves)
      end
      return mvKarte[en] or en
    end
    P._deutschAbilityName = P._deutschAbilityName or P.abilityName
    P.abilityName = function(...)
      local en = P._deutschAbilityName(...)
      if not abKarte then
        if not P._abilityNames then return en end
        abKarte = karte(P._romAbilityNames or P._abilityNames, DE.abilities)
      end
      return abKarte[en] or en
    end
  end)
  pcall(function()
    local ID = require("src.core.game3.items_data")
    ID._deutschInstallPack = ID._deutschInstallPack or ID.installPack
    ID.installPack = function(pack, ...)
      local list = type(pack) == "table" and pack.items or {}
      -- vor dem Aufruf die EN-Werte zurueck (falls dieselbe Tabelle erneut kommt), damit der Namensindex
      -- (_byName) immer aus den englischen Namen gebaut wird
      for _, e in pairs(list) do
        if type(e) == "table" and e._enName then e.name, e.description = e._enName, e._enDesc end
      end
      local r = ID._deutschInstallPack(pack, ...)
      for i, e in pairs(list) do
        local d = DE.items[tonumber(i) or -1]
        if type(e) == "table" and d then
          e._enName, e._enDesc = e.name, e.description
          if d.name and d.name ~= "" then e.name = d.name end
          if d.description and d.description ~= "" then e.description = d.description end
        end
      end
      return r
    end
    if ID._pack then ID.installPack(ID._pack) end
  end)

  -- ------------------------------------------------------------ Fundort im Trainer-Memo
  -- Das Spiel speichert den Ortsnamen beim Fangen als (EN-)Text im Pokemon (metLocationName).  Der
  -- Spielstand bleibt so; nur die Anzeige bekommt den DE-Namen.
  pcall(function()
    if #(R.orte or {}) == 0 then return end
    local orte
    local function ersetze(s)
      if type(s) ~= "string" then return s end
      if not orte then
        -- erst beim ersten Memo: dann sind die Strings-Overrides sicher aktiv
        orte = {}
        for _, en in ipairs(R.orte) do
          local ok, de = pcall(function() return require("src.core.Strings")(en) end)
          if ok and type(de) == "string" and de ~= "" and de ~= en then orte[#orte + 1] = { en, de } end
        end
        table.sort(orte, function(x, y) return #x[1] > #y[1] end)
      end
      for _, p in ipairs(orte) do
        local a, e = s:find(p[1], 1, true)
        if a then s = s:sub(1, a - 1) .. p[2] .. s:sub(e + 1) end
      end
      return s
    end
    local SD = require("src.core.game3.summary_data")
    local alt = SD.formatTrainerMemo
    SD.formatTrainerMemo = function(...)
      local zeilen = alt(...)
      if type(zeilen) == "table" then
        for i, z in ipairs(zeilen) do zeilen[i] = ersetze(z) end
      end
      return zeilen
    end
  end)

  -- ------------------------------------------------------------ Datendateien
  local DATEN = {}
  for rel, karte in pairs(R.daten or {}) do
    local m = {}
    for en, teile in pairs(karte) do
      if type(en) == "string" and (en:sub(1, 1) == "%" or en:sub(1, 1) == "^") then
        m[en] = teile                     -- eingebettetes IR: DE-Adresse (Zahl), dekodiert beim Ersetzen
      else
        m[en] = W.teile(teile):gsub("\f", "\n"):gsub("\v", "\n")
      end
    end
    DATEN[rel] = m
  end
  local IR = {}
  for _, rel in ipairs(R.irDateien or {}) do IR[rel] = true end
  -- Manifest-Felder mit Klartext + IR (Beerenmixer: texts[k], irs[k]) -> DE-Text der Adresse R.feldTexte[Datei][k]
  local FELD = R.feldTexte or {}
  for rel in pairs(FELD) do IR[rel] = IR[rel] or false end
  local TextIR = require("src.core.game3.scripting.text_ir")
  local function feldText(off)
    if W.ver ~= "emerald" then
      -- rs/extract_berry_blender.lua: IR.toAscii(IR.decode(bytes, { dialect = "rs" }))
      return TextIR.toAscii(W.decodeAt(off, false))
    end
    -- rse/berry_blender_extract.lua decode(): Glyphenfolge $55-$59 = "POKéBLOCK", Rest ueber toPlain
    local stop = W.rom:find("\255", off + 1, true)
    local bytes = { W.rom:byte(off + 1, stop) }
    local opts = { dialect = TextIR.dialectOf(W.ver) }
    local function teil(b)
      if #b == 0 then return "" end
      return W.mitZeichen(function() return TextIR.toPlain(TextIR.decode(b, opts), {}) end)
    end
    local teile, cur, i = {}, {}, 1
    while i <= #bytes do
      if bytes[i] == 0x55 and bytes[i + 1] == 0x56 and bytes[i + 2] == 0x57 and bytes[i + 3] == 0x58 and bytes[i + 4] == 0x59 then
        teile[#teile + 1] = teil(cur) .. "POKéBLOCK"
        cur, i = {}, i + 5
      else
        cur[#cur + 1] = bytes[i]
        i = i + 1
      end
    end
    teile[#teile + 1] = teil(cur)
    return table.concat(teile)
  end
  local function zielVon(pfad)
    if type(pfad) ~= "string" then return nil end
    for rel in pairs(DATEN) do
      if pfad:sub(-#rel) == rel then return rel end
    end
    for rel in pairs(IR) do
      if pfad:sub(-#rel) == rel then return rel end
    end
  end
  local function ser(v)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t ~= "table" then return tostring(v) end
    local teile = {}
    for k, w in pairs(v) do
      local key = type(k) == "number" and ("[" .. k .. "]") or ("[" .. string.format("%q", k) .. "]")
      teile[#teile + 1] = key .. "=" .. ser(w)
    end
    return "{" .. table.concat(teile, ",") .. "}"
  end
  local isBattle = {}
  for _, k in ipairs(R.battle or {}) do isBattle[k] = true end
  local fertig = {}
  local function deutscheQuelle(rel, src)
    if fertig[rel] then return fertig[rel] end
    local chunk = (loadstring or load)(src, "@" .. rel)
    if not chunk then return src end
    if setfenv then setfenv(chunk, {}) end
    local ok, tab = pcall(chunk)
    if not ok or type(tab) ~= "table" then return src end
    local m = DATEN[rel]
    local function walk(x)
      for k, w in pairs(x) do
        if m and type(w) == "string" and m[w] then x[k] = m[w]
        elseif type(w) == "table" then
          -- eingebetteter Text: { ir = {...}, key = "g3:...", name = Label } -> DE-ir aus der ROM
          if IR[rel] and type(w.ir) == "table" and type(w.key) == "string" and R.text and R.text[w.key] then
            local okD, ir = pcall(W.decodeAt, R.text[w.key], isBattle[w.key])
            if okD and ir then w.ir = ir end
          end
          walk(w)
        end
      end
    end
    walk(tab)
    for k, off in pairs(FELD[rel] or {}) do
      if type(tab.irs) == "table" and tab.irs[k] ~= nil then
        local okD, ir = pcall(W.decodeAt, off, false)
        if okD and ir then tab.irs[k] = ir end
      end
      if type(tab.texts) == "table" and tab.texts[k] ~= nil then
        local okT, s = pcall(feldText, off)
        if okT and s then tab.texts[k] = s end
      end
    end
    -- Feldgenaue Werte "@<pfad>" (Anzeigefelder einzelner Eintraege, z. B. "@trainers.5.className"):
    -- nur genau dieses Feld wird gesetzt und nur, wenn dort ein String steht
    for k, w in pairs(m or {}) do
      if k:sub(1, 1) == "@" then
        local node, teile = tab, {}
        for p in k:sub(2):gmatch("[^.]+") do teile[#teile + 1] = tonumber(p) or p end
        for i = 1, #teile - 1 do
          node = type(node) == "table" and node[teile[i]] or nil
        end
        local last = teile[#teile]
        if type(node) == "table" and type(node[last]) == "string" then node[last] = w end
      elseif k:sub(1, 1) == "^" then
        -- Rohbytes (textBytes; Rubin/Saphir-Bildschirme dekodieren sie selbst): DE-Bytes ab Adresse w bis $FF
        local node, teile = tab, {}
        for p in k:sub(2):gmatch("[^.]+") do teile[#teile + 1] = tonumber(p) or p end
        for i = 1, #teile - 1 do
          node = type(node) == "table" and node[teile[i]] or nil
        end
        local last = teile[#teile]
        local stop = W.rom:find("\255", w + 1, true)
        if type(node) == "table" and type(node[last]) == "table" and stop then
          node[last] = { W.rom:byte(w + 1, stop) }
        end
      elseif k:sub(1, 1) == "%" then
        -- eingebettetes IR ({ {t="text", s=...}, {t="nl"}, ... }) als Ganzes: DE-Text ab der Adresse w
        local node, teile = tab, {}
        for p in k:sub(2):gmatch("[^.]+") do teile[#teile + 1] = tonumber(p) or p end
        for i = 1, #teile - 1 do
          node = type(node) == "table" and node[teile[i]] or nil
        end
        local last = teile[#teile]
        if type(node) == "table" and type(node[last]) == "table" then
          local okD, ir = pcall(W.decodeAt, w, false)
          if okD and ir then node[last] = ir end
        end
      end
    end
    -- Eintragsgenaue Werte "#<Index>.<Feld>" (z. B. Pokedex-Kategorie: ein EN-Wort hat je nach Pokemon
    -- verschiedene DE-Uebersetzungen)
    for k, w in pairs(m or {}) do
      local i, f = k:match("^#(%d+)%.([%w_]+)$")
      local e = i and tab[tonumber(i)]
      if type(e) == "table" and e[f] ~= nil then e[f] = w end
    end
    fertig[rel] = "return " .. ser(tab)
    return fertig[rel]
  end
  pcall(function()
    local CacheFs = require("src.import.CacheFs")
    CacheFs._deutschReadAt = CacheFs._deutschReadAt or CacheFs.readAt
    CacheFs.readAt = function(rel, ...)
      local src = CacheFs._deutschReadAt(rel, ...)
      local ziel = type(src) == "string" and zielVon(rel)
      if ziel then return deutscheQuelle(ziel, src) end
      return src
    end
  end)
  -- Kit.loadLua (RS/RSE-Statusseite, Attacken-Neulerner) laedt ueber love.filesystem.load; im Mod ist
  -- love.filesystem abgeschirmt -> die Huelle sitzt an Kit.loadLua selbst
  pcall(function()
    local Kit = require("src.ui.game3.rse.scene_kit")
    Kit._deutschLoadLua = Kit._deutschLoadLua or Kit.loadLua
    local fertigTab = {}
    Kit.loadLua = function(pfad, ...)
      local ziel = zielVon(pfad)
      if not ziel then return Kit._deutschLoadLua(pfad, ...) end
      if fertigTab[ziel] == nil then
        local src = require("src.import.CacheFs").readAt(pfad)
        local chunk = type(src) == "string" and (loadstring or load)(src, "@" .. pfad)
        local ok, tab = false, nil
        if chunk then ok, tab = pcall(chunk) end
        fertigTab[ziel] = (ok and type(tab) == "table") and tab or false
      end
      if fertigTab[ziel] then return fertigTab[ziel] end
      return Kit._deutschLoadLua(pfad, ...)
    end
  end)
end
