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
  -- Dateien, deren Port-Extraktor Platzhalter als eigene Marken schreibt (W.teile wuerde sie verwerfen):
  -- Spielername, Rivale, Textvariablen; Questlog zusaetzlich $F7 <n> -> {D<n>}.  Wie die Extraktoren in
  -- src/import/gba (quest_log_extract, help_extract, fame_checker_extract, Duellturm-Rekorde).
  local function strVar(n) return "{STR_VAR_" .. n .. "}" end
  local PLATZHALTER = {
    ["quest_log/pack.lua"] = { strvar = function(n) return "{S" .. n .. "}" end, f7 = true, ohneTags = true },
    ["help/pack.lua"] = { strvar = function(n) return n == 1 and "{PC_OWNER}" or "" end, ohneTags = true,
      f9 = { [0] = "↑", [1] = "↓", [2] = "←", [3] = "→", [4] = "+", [10] = "①", [11] = "②", [12] = "③",
             [13] = "④", [14] = "⑤", [15] = "⑥", [16] = "⑦", [17] = "⑧", [18] = "⑨", [19] = "(",
             [20] = ")", [21] = "◎", [22] = "△", [23] = "✕" } },
    ["fame_checker/pack.lua"] = { strvar = strVar, para = "\\p", scroll = "\\l", ohneTags = true },
    ["rse/battle_tower_records/manifest.lua"] = { strvar = strVar },
  }
  local function platzhalterText(off, len, stil)
    local out, bytes = {}, {}
    local function flush()
      for _, s in ipairs(W.decodeBytes(bytes) or {}) do
        if s.t == "text" then out[#out + 1] = s.s
        elseif s.t == "nl" then out[#out + 1] = "\n"
        elseif s.t == "para" then out[#out + 1] = stil.para or "\n"
        elseif s.t == "scroll" then out[#out + 1] = stil.scroll or "\n"
        elseif s.t == "player" then out[#out + 1] = "{PLAYER}"
        elseif s.t == "rival" then out[#out + 1] = "{RIVAL}"
        elseif s.t == "strvar" then out[#out + 1] = stil.strvar(s.n)
        elseif s.t == "tag" and s.tag and not stil.ohneTags then out[#out + 1] = s.tag end
      end
      bytes = {}
    end
    local stop = off + len
    while off < stop do
      local b = W.rom:byte(off + 1)
      off = off + 1
      if not b or b == 255 then break end
      if b == 0xF7 and stil.f7 then
        flush()
        out[#out + 1] = "{D" .. (W.rom:byte(off + 1) or 0) .. "}"
        off = off + 1
      elseif b == 0xF9 and stil.f9 then
        flush()
        out[#out + 1] = stil.f9[W.rom:byte(off + 1) or -1] or ""
        off = off + 1
      else
        bytes[#bytes + 1] = b
      end
    end
    bytes[#bytes + 1] = 0xFF
    flush()
    return table.concat(out)
  end
  for rel, karte in pairs(R.daten or {}) do
    local m = {}
    local stil = PLATZHALTER[rel]
    for en, teile in pairs(karte) do
      if type(en) == "string" and (en:sub(1, 1) == "%" or en:sub(1, 1) == "^") then
        m[en] = teile                     -- eingebettetes IR: DE-Adresse (Zahl), dekodiert beim Ersetzen
      elseif stil and type(teile) == "table" and #teile == 1 and type(teile[1]) == "table" then
        local ok, s = pcall(platzhalterText, teile[1][1], teile[1][2], stil)
        m[en] = ok and s or W.teile(teile)
      else
        m[en] = W.teile(teile):gsub("\f", "\n"):gsub("\v", "\n")
      end
    end
    DATEN[rel] = m
  end
  -- Abspann (R.abspann): die deutschen Editionen haben andere Seiten bzw. Mitwirkende (Rubin/Saphir 49 statt
  -- 52 Seiten, Smaragd 55 statt 57, Feuerrot/Blattgruen deutsches Team) -> wird ganz aus der DE-ROM neu gebaut
  local ABSPANN = R.abspann
  if ABSPANN then DATEN[ABSPANN.datei] = DATEN[ABSPANN.datei] or {} end
  local IR = {}
  for _, rel in ipairs(R.irDateien or {}) do IR[rel] = true end
  -- Manifest-Felder mit Klartext + IR (Beerenmixer: texts[k], irs[k]) -> DE-Text der Adresse R.feldTexte[Datei][k]
  local FELD = R.feldTexte or {}
  for rel in pairs(FELD) do IR[rel] = IR[rel] or false end
  local TextIR = require("src.core.game3.scripting.text_ir")
  -- Abspann neu aufbauen, Aufbau wie die Port-Extraktoren (src/import/gba/rs/extract_credits.lua,
  -- rse/credits_extract.lua, credits_extract.lua), nur aus der deutschen Tabelle
  local function zeiger(off)
    local a, b, c, d = W.rom:byte(off + 1, off + 4)
    local p = a and (a + b * 256 + c * 65536 + d * 16777216 - 0x08000000)
    if p and p >= 0 and p < #W.rom then return p end
  end
  local function bisEnde(off)
    local stop = W.rom:find("\255", off + 1, true)
    return { W.rom:byte(off + 1, stop) }
  end
  local function abspannText(off)
    local out = {}
    local segs = W.mitZeichen(TextIR.decode, string.char(unpack(bisEnde(off))))
    for _, seg in ipairs(segs or {}) do
      if seg.t == "nl" then out[#out + 1] = "\n"
      elseif seg.t == "ext" and seg.cmd == 0x13 then out[#out + 1] = string.format("{CLEAR_TO %d}", seg.args[1])
      elseif seg.t == "text" then out[#out + 1] = seg.s end
    end
    return table.concat(out)
  end
  local function abspannNeu(tab)
    local A = ABSPANN
    if A.art == "rs" or A.art == "rse" then
      local seiten = {}
      for s = 0, A.seiten - 1 do
        local zeilen = {}
        for z = 0, 4 do
          local e = assert(zeiger(A.tabelle + (s * 5 + z) * 4), "Abspann-Eintrag")
          local t = zeiger(e + 4)
          local raw = t and bisEnde(t) or { 255 }
          local text = W.mitZeichen(function()
            return TextIR.toPlain(TextIR.decode(raw, A.art == "rs" and { dialect = "rs" } or nil), {})
          end)
          if A.art == "rs" then
            local titel = raw[1] == 0xFC and raw[2] == 3 and raw[3] == 9
            zeilen[#zeilen + 1] = { isTitle = titel, text = text, raw = raw, nativeX = W.rom:byte(e + 1),
              palette = titel and 9 or 8 }
          else
            zeilen[#zeilen + 1] = { isTitle = W.rom:byte(e + 2) ~= 0, text = text }
          end
        end
        seiten[#seiten + 1] = zeilen
      end
      -- pageCount bleibt (die Cache-Pruefung des Ports verlangt 52 bzw. den US-Wert und liest ueber dieselbe
      -- Huelle); die Abspann-Anzeige uebernimmt dePageCount beim Laden (Huelle an gba_machine unten)
      tab.pages, tab.dePageCount = seiten, A.seiten
      if A.wechsel then tab.pageTransitions = A.wechsel end
    elseif A.art == "frlg" then
      if A.titel then tab.title = abspannText(A.titel) end
      tab.texts = tab.texts or {}
      for i = 0, A.anzahl - 1 do
        local b = A.texte + i * 12
        tab.texts[i] = { title = abspannText(assert(zeiger(b), "Abspann-Titel")),
          names = abspannText(assert(zeiger(b + 4), "Abspann-Namen")), unused = W.rom:byte(b + 9) ~= 0 }
      end
    end
  end
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
  -- Zuordnung Pfad -> Rezeptdatei: laengster Treffer mit Verzeichnisgrenze.  (Frueher reichte das Dateiende;
  -- "frontier/trainers.lua" passte dann auch auf "trainers.lua" -- je nach pairs-Reihenfolge wurden die
  -- beiden Dateien vertauscht und das falsche Ergebnis in fertig[] zwischengespeichert.)
  local function passt(pfad, rel)
    -- Rezeptpfade sind relativ zu data/generated/gba/
    return pfad == rel or pfad:sub(-#rel - 4) == "gba/" .. rel
  end
  local function zielVon(pfad)
    if type(pfad) ~= "string" then return nil end
    local best
    for _, tab in ipairs({ DATEN, IR }) do
      for rel in pairs(tab) do
        if passt(pfad, rel) and (not best or #rel > #best) then best = rel end
      end
    end
    return best
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
        -- englischer Text der Datei -> DE-Text ueber seine Pruefsumme (das Rezept fuehrt keine Spieltexte)
        local de = m and type(w) == "string" and w ~= "" and W.nachText(m, w)
        if de then x[k] = de
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
        -- { Adresse, "bis_absatz" }: nur bis zum ersten Absatz (die DE-ROM fasst manche kurzen US-Texte mit dem
        -- folgenden zu einem zusammen, z. B. Smaragd-Geheimgeschehen „Danke, dass du …“)
        local adr, bisAbsatz = w, false
        if type(w) == "table" then adr, bisAbsatz = w[1], w[2] == "bis_absatz" end
        if type(node) == "table" and type(node[last]) == "table" then
          local okD, ir = pcall(W.decodeAt, adr, false)
          if okD and ir and bisAbsatz then
            for i, e in ipairs(ir) do
              if type(e) == "table" and e.t == "para" then
                for j = #ir, i, -1 do ir[j] = nil end
                break
              end
            end
          end
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
    if ABSPANN and rel == ABSPANN.datei then
      local ok, err = pcall(abspannNeu, tab)
      if not ok then log:warn("Deutsch Gen 3: Abspann: %s", tostring(err)) end
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
  -- Port 0.3.89 laedt manche dieser Dateien schon vor dem Mod und haelt sie im Speicher (Trainer: Namen und
  -- Klassen im Kampf blieben englisch; Mehrfachauswahl-Menues).  Nach dem Einklinken verwerfen bzw. neu laden,
  -- damit sie durch readAt oben gehen.  (Gefunden mit Test/werkzeug/probe_gen3_daten.lua.)
  -- (require statt package.loaded: in der Mod-Umgebung ist package.loaded abgeschirmt)
  pcall(function()
    local Tr = require("src.core.game3.scripting.trainers")
    if type(Tr) == "table" then Tr._pack = nil end
  end)
  -- Hilfe-System und Questlog (Feuerrot/Blattgruen) installiert Game3 beim Start aus dem Cache; neu laden
  pcall(function()
    local Dataset = require("src.core.game3.dataset")
    local c = Dataset.cache()
    if c then
      local Help = require("src.ui.game3.help_system")
      if Help.pack then Help.install(c) end
      local QL = require("src.ui.game3.quest_log")
      if QL.pack then QL.install(c) end
    end
  end)
  pcall(function()
    local MC = require("src.core.game3.scripting.multichoice")
    if type(MC) == "table" and type(MC.tryLoadCache) == "function" then
      MC.LISTS = {}
      MC.tryLoadCache()
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
  -- Abspann Rubin/Saphir/Smaragd (ui/game3/rse/credits.lua) laedt sein Manifest ueber Machine:manifest mit
  -- love.filesystem.load, also am readAt-Haken vorbei -> deutsches Manifest einsetzen, dePageCount anwenden
  pcall(function()
    local Machine = require("src.ui.game3.rse.gba_machine")
    Machine._deutschManifest = Machine._deutschManifest or Machine.manifest
    Machine.manifest = function(self, pfad, ...)
      local ziel = type(pfad) == "string" and zielVon(pfad)
      if ziel and self.manifests and self.manifests[pfad] == nil then
        local src = require("src.import.CacheFs").readAt(pfad)
        local chunk = type(src) == "string" and (loadstring or load)(src, "@" .. pfad)
        local ok, tab = false, nil
        if chunk then ok, tab = pcall(chunk) end
        if ok and type(tab) == "table" then
          if tab.dePageCount then tab.pageCount = tab.dePageCount end
          self.manifests[pfad] = tab
        end
      end
      return Machine._deutschManifest(self, pfad, ...)
    end
  end)
  -- Namenseingabe (src/ui/game3/naming.lua) laedt ihr Manifest ebenfalls mit love.filesystem.load; die
  -- Ueberschrift ("YOUR NAME?" ...) steht in templates[i].title -> Ueberschrift aus dem deutschen Manifest
  pcall(function()
    local Naming = require("src.ui.game3.naming")
    local Kit = require("src.ui.game3.rse.scene_kit")
    Naming._deutschTpl = Naming._deutschTpl or Naming.templateFromManifest
    Naming.templateFromManifest = function(man, name, ...)
      local tpl = Naming._deutschTpl(man, name, ...)
      local ok, de = pcall(Kit.loadLua, "data/generated/gba/naming/manifest.lua")
      if ok and type(de) == "table" and type(tpl) == "table" then
        local ok2, dtpl = pcall(Naming._deutschTpl, de, name)
        if ok2 and type(dtpl) == "table" and dtpl.title then
          local kopie = {}
          for k, v in pairs(tpl) do kopie[k] = v end
          kopie.title = dtpl.title
          return kopie
        end
      end
      return tpl
    end
  end)
end
