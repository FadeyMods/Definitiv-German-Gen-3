-- Deutsch Gen 3: Kasten-/Layout-Anpassungen an die deutsche ROM.
-- Wird von gen3_main.lua geladen: install(ctx), ctx = { mod, R (Rezept), ver, log }.
-- Grundlage: g3_fenster.py (WindowTemplate EN gegen DE, gen3/<spiel>/fenster.tsv) und die
-- Bildschirmpruefung tests/layout_gen3.lua.  Es werden nur Masse geaendert, die die DE-ROM
-- nachweislich anders hat; keine ROM-Inhalte in dieser Datei.

local function hulle(modul, name, neu)
  local ok, M = pcall(require, modul)
  if not ok or type(M) ~= "table" or type(M[name]) ~= "function" then return false end
  local alt = M[name]
  M[name] = neu(alt, M)
  return true
end

-- FR/BG Karte: sRegionMapWindowTemplates[3]/[4] (Kopfzeile links/rechts) sind in der DE-ROM
-- 6 statt 5 Kacheln breit (EN 18,0 5x2 / 24,0 5x2 -> DE 18,0 6x2 / 24,0 6x2).  Der Port fuellt
-- den Hintergrund der beiden Felder mit 40 px Breite; DE braucht 48 px.
local function karteKopfzeile(log)
  return hulle("src.ui.game3.region_map", "draw", function(alt, Modul)
    return function(...)
      local rect = love.graphics.rectangle
      love.graphics.rectangle = function(mode, x, y, w, h, ...)
        if mode == "fill" and y == 0 and w == 40 and h == 16 and (x == 144 or x == 192) then w = 48 end
        return rect(mode, x, y, w, h, ...)
      end
      local ok, err = pcall(alt, ...)
      love.graphics.rectangle = rect
      if not ok then error(err, 0) end
    end
  end)
end

-- Smaragd Kampf: sStandardBattleWindowTemplates/sBattleArenaWindowTemplates (DE-ROM):
--   [0]/[22] Meldung      EN 2,15 26x4 -> DE 2,15 27x4
--   [12]     B_WIN_YESNO  EN 26,9 3x4  -> DE 25,9 4x4
local SMARAGD_KAMPF = { [0] = { w = 27 }, [12] = { left = 25, w = 4 }, [22] = { w = 27 } }

local function kampfFenster()
  return hulle("src.ui.game3.battle_chrome", "window", function(alt, Modul)
    return function(id, ...)
      local w = alt(id, ...)
      local p = SMARAGD_KAMPF[tonumber(id) or 0]
      if p and type(w) == "table" then
        if p.left then w.left, w.x = p.left, p.left * 8 end
        if p.w then w.w = p.w end
      end
      return w
    end
  end)
end

-- Smaragd Auswahlkasten (YES/NO) im Kampf: Cmd_yesnobox, Cmd_yesnoboxlearnmove, Cmd_yesnoboxstoplearningmove
-- rufen in der DE-ROM HandleBattleWindow(23, 8, 29, 13) statt (24, ...) auf, der Pfeil
-- (BattleCreateYesNoCursorAt) steht auf Kachel 24 statt 25, der Text in Fenster 12 auf 25 statt 26.
-- Alles eine Kachel weiter links, Rahmen innen 5 statt 4 Kacheln breit.
local function kampfJaNein()
  return hulle("src.ui.game3.choice", "battleYesNoGeometry", function(alt, Modul)
    return function(layout, L, Tp, ...)
      if layout ~= "emerald" then return alt(layout, L, Tp, ...) end
      local g = alt(layout, (L or 24) - 1, Tp, ...)
      if type(g) == "table" and type(g.frame) == "table" then g.frame.width = 5 end
      return g
    end
  end)
end

-- Smaragd Briefbox (PC): die DE-ROM legt das Titelfenster nicht fest 8 Kacheln breit an, sondern
-- MailboxMenu_AddWindow rechnet  Breite = (StringWidth(gText_Mailbox) + 9) / 8 + 2  Kacheln
-- (Vorlage 1,1 24x2 als Hoechstmass), und Mailbox_DrawMailboxMenu zentriert den Titel auf
-- Breite*8 statt auf 0x40.
local function briefboxTitel()
  return hulle("src.ui.game3.rse.mailbox", "draw", function(alt, Modul)
    return function(...)
      local M = Modul
      local t = M and M.WIN and M.WIN.title
      if not (t and M.open and M.state == "list") then return alt(...) end
      local FrlgFont = require("src.ui.game3.frlg_font")
      local Window = require("src.ui.game3.window")
      local titel = require("src.core.game3.rom_text").plain("gText_Mailbox")
      local tw = FrlgFont.measure(titel)
      local kacheln = math.min(24, math.floor((tw + 9) / 8) + 2)
      t.width, t.w = kacheln, kacheln
      local print = Window.printPx
      Window.printPx = function(text, px, py, ...)
        if text == titel and py == t.top * 8 + 1 then
          px = t.left * 8 + math.floor((kacheln * 8 - tw) / 2)
        end
        return print(text, px, py, ...)
      end
      local ok, err = pcall(alt, ...)
      Window.printPx = print
      if not ok then error(err, 0) end
    end
  end)
end

-- Smaragd Geheimbasis-Register: sRegistryWindowTemplates[0] EN 18,1 11x18 -> DE 17,1 12x18.
-- Die Vorlage ist im Port lokal (REG_WIN) und der Mod hat kein debug -> beim Zeichnen der
-- Registerliste Rahmen, Text und Pfeil um eine Kachel nach links / Rahmen eine Kachel breiter.
local function registerFenster()
  return hulle("src.ui.game3.rse.decoration", "draw", function(alt, D)
    return function(...)
      if not (D and D.view == "registry") then return alt(...) end
      local Window = require("src.ui.game3.window")
      local frameF, fillF, printF, cursorF = Window.stdFrame, Window.fill, Window.printPx, Window.cursorPx
      local function de(tpl)
        if type(tpl) == "table" and (tpl.left or tpl.tilemapLeft) == 18 and (tpl.top or tpl.tilemapTop) == 1
          and (tpl.w or tpl.width) == 11 and (tpl.h or tpl.height) == 18 then
          local c = {}
          for k, v in pairs(tpl) do c[k] = v end
          c.left, c.tilemapLeft, c.w, c.width = 17, 17, 12, 12
          return c
        end
        return tpl
      end
      Window.stdFrame = function(tpl, ...) return frameF(de(tpl), ...) end
      Window.fill = function(tpl, ...) return fillF(de(tpl), ...) end
      Window.printPx = function(text, px, ...)
        if type(px) == "number" and px >= 144 and px < 232 then px = px - 8 end
        return printF(text, px, ...)
      end
      Window.cursorPx = function(px, ...)
        if type(px) == "number" and px >= 144 and px < 232 then px = px - 8 end
        return cursorF(px, ...)
      end
      local ok, err = pcall(alt, ...)
      Window.stdFrame, Window.fill, Window.printPx, Window.cursorPx = frameF, fillF, printF, cursorF
      if not ok then error(err, 0) end
    end
  end)
end

-- Smaragd PokeNav-Karte: sMapSecInfoWindowTemplate EN 17,4 12x13 -> DE 17,4 13x13
local function navInfoFenster()
  return hulle("src.ui.game3.rse.pokenav.region_map", "drawInfo", function(alt, Modul)
    return function(...)
      local Kit = require("src.ui.game3.rse.scene_kit")
      local uf = Kit.userFrame
      Kit.userFrame = function(tx, ty, tw, th, ...)
        if tx == 17 and ty == 4 and tw == 12 and th == 13 then tw = 13 end
        return uf(tx, ty, tw, th, ...)
      end
      local ok, err = pcall(alt, ...)
      Kit.userFrame = uf
      if not ok then error(err, 0) end
    end
  end)
end

-- Rubin/Saphir: die DE-Masse stehen in pokeruby als '#if GERMAN'-Zweige (Quelle: quellen/pret/pokeruby).

-- option_menu.c: TEXTSPEED_*_LEFT 120/155/184 -> 120/161/202, BATTLESTYLE_SET 190 -> 178;
-- Rahmen: DE druckt gSystemText_Type + Nummer als eine Zeichenkette ab 120 (EN: "TYPE" bei 120, Nummer bei 144)
local function rsOptionen()
  return hulle("src.ui.game3.rs.option_menu", "show", function(alt, Modul)
    return function(...)
      local r = alt(...)
      local M = Modul
      local d = M and M._data
      if type(d) == "table" and not d._deLayout and type(d.rows) == "table" then
        local function setze(i, xs)
          local row = d.rows[i]
          if row and row.choices then
            for j, x in pairs(xs) do if row.choices[j] then row.choices[j].x = x end end
          end
        end
        setze(1, { 120, 161, 202 })
        setze(3, { [2] = 178 })
        if d.frameLabel and d.frameLabelX then
          d.frameNumberX = d.frameLabelX + require("src.ui.game3.frlg_font").measure(d.frameLabel)
        end
        d._deLayout = true
      end
      return r
    end
  end)
end

-- party_menu.c: WINDOW_LEFT/RIGHT 3/26 -> 0/29 (Meldung im Teammenue), Text ab Kachel 1
local function rsTeamMeldung()
  return hulle("src.ui.game3.rs.party_menu_data", "drawMessage", function(alt, Modul)
    return function(value, ...)
      require("src.ui.game3.chrome").stdFrame(1, 15, 28, 4)
      if value then
        local D = Modul
        local Font = require("src.ui.game3.frlg_font")
        local opts = D.menuTextOptions()
        opts.maxWidth, opts.linePitch = 224, 16
        Font.draw(Font.wrap(value, 224, opts), 8, 120, opts)
      end
    end
  end)
end

-- main_menu.c PrintPlayTime/PrintBadgeCount: DE gMainMenuString_Time/_Badges bei x=124 statt Kachel 16 (128)
local function rsWeiterKasten()
  local ok, M = pcall(require, "src.ui.game3.rs.main_menu")
  if not ok or type(M) ~= "table" or type(M._drawContinue) ~= "function" then return false end
  local alt = M._drawContinue
  M._drawContinue = function(self, ...)
    local Font = require("src.ui.game3.frlg_font")
    local RomText = require("src.core.game3.rom_text")
    local zeit, orden = RomText.plain("gMainMenuString_Time"), RomText.plain("gMainMenuString_Badges")
    local draw = Font.draw
    Font.draw = function(text, x, ...)
      if x == 128 and (text == zeit or text == orden) then x = 124 end
      return draw(text, x, ...)
    end
    local ok2, err = pcall(alt, self, ...)
    Font.draw = draw
    if not ok2 then error(err, 0) end
  end
  return true
end

-- pokemon_summary_screen.c PrintTrainerMemo: EN  <Wesen>[Terminator4]gOtherText_Nature ...
--                                          DE  gOtherText_Nature<Wesen>gOtherText_Terminator4 ...
local function rsMemo()
  return hulle("src.ui.game3.rs.summary_policy", "memo", function(alt, Modul)
    return function(mon, ...)
      local runs = alt(mon, ...)
      local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
      if type(runs) ~= "table" or #runs < 2 or (ok and Pokemon.isEgg and Pokemon.isEgg(mon)) then return runs end
      local RomText = require("src.core.game3.rom_text")
      local nat, term = RomText.plain("gOtherText_Nature"), RomText.plain("gOtherText_Terminator4")
      local k = (runs[2] and runs[2].text == term) and 3 or 2
      if not (runs[k] and runs[k].text == nat) then return runs end
      local neu = { { text = nat, color = 255 }, runs[1], { text = term, color = 255 } }
      for i = k + 1, #runs do neu[#neu + 1] = runs[i] end
      return neu
    end
  end)
end

-- pokemon_summary_screen.c (Attackenseiten): Name ab Kachel 15, danach setzt
-- SummaryScreen_PlaceTextTile_White(1, 24, y) die PP-Kachel und Menu_PrintText(.., 25, y) die Zahlen --
-- beide ueberschreiben, was der Name rechts von x=192 gezeichnet hat.  Lange DE-Namen enden also bei 192.
local function rsAttackenKappen()
  return hulle("src.ui.game3.rs.summary_menu", "draw", function(alt, Modul)
    return function(...)
      local S = Modul
      if not (S and (S._page or 0) >= 2) then return alt(...) end
      local Font = require("src.ui.game3.frlg_font")
      local draw = Font.draw
      Font.draw = function(text, x, y, opts, ...)
        if x == 120 and type(text) == "string" and type(y) == "number" and y >= 32 and y <= 96 and (y - 32) % 16 == 0
          and Font.measure(text, opts) > 72 then
          local t = text
          while #t > 0 and Font.measure(t, opts) > 72 do
            -- letztes UTF-8-Zeichen entfernen (Folgebytes 0x80-0xBF, dann das Startbyte)
            local e = #t
            while e > 1 and t:byte(e) >= 0x80 and t:byte(e) < 0xC0 do e = e - 1 end
            t = t:sub(1, e - 1)
          end
          text = t
        end
        return draw(text, x, y, opts, ...)
      end
      local ok, err = pcall(alt, ...)
      Font.draw = draw
      if not ok then error(err, 0) end
    end
  end)
end

-- trainer_card.c (Rueckseite): EN haengt gOtherText_TrainersTrainerCard an den Namen an, DE setzt den
-- Namen mit de_sub_8073174 an die Platzhalterstelle des Textes ein.
local function rsPassTitel()
  return hulle("src.ui.game3.rs.trainer_card", "texts", function(alt, Modul)
    return function(card, side, ...)
      local out = alt(card, side, ...)
      if side == "front" or type(out) ~= "table" or type(card) ~= "table" then return out end
      local okR, RomText = pcall(require, "src.core.game3.rom_text")
      local ok, roh = false, nil
      if okR then ok, roh = pcall(RomText.plain, "gOtherText_TrainersTrainerCard", { stringVars = { "\1" }, playerName = "\1" }) end
      if not ok or type(roh) ~= "string" or not roh:find("\1", 1, true) then return out end
      local T = Modul
      local Font = require("src.ui.game3.frlg_font")
      local name = tostring(card.name or "")
      for _, e in ipairs(out) do
        if e.id == "name" then
          e.text = roh:gsub("\1", function() return name end)
          e.x = 224 - Font.measure(e.text, T.textOptions(e.kind)) % 256
        end
      end
      return out
    end
  end)
end

-- berry_tag_screen.c: DE druckt Name + gOtherText_Berry2 (EN nur den Namen)
local function rsBeerenName()
  return hulle("src.ui.game3.rs.berry_tag", "berryInfo", function(alt, Modul)
    return function(...)
      local info = alt(...)
      if type(info) ~= "table" or type(info.name) ~= "string" then return info end
      local ok, zusatz = pcall(require("src.core.game3.rom_text").plain, "gOtherText_Berry2")
      if not ok or type(zusatz) ~= "string" or zusatz == "" then return info end
      local kopie = setmetatable({}, { __index = info })
      for k, v in pairs(info) do kopie[k] = v end
      kopie.name = info.name .. zusatz
      return kopie
    end
  end)
end

-- ---------------------------------------------------------------------------------------------
-- Pokedex: Groesse/Gewicht.  Die DE-ROMs rechnen nicht in Fuss/Pfund, sondern geben die Rohwerte
-- (Dezimeter/Hektogramm aus gPokedexEntries) mit Komma aus.  Je Spiel nach dem DE-Code:
--   FR/BG   (DE-Funktion fuer beide Werte, statt DexScreen_PrintMonHeight/Weight):
--           Bezeichnung bei x; Zahl bei x+44: [v/1000 | Leerz.][(v%1000)/100 | Leerz.][(v%100)/10],[v%10]
--           (unbekannt: ???,?); Einheit (gText_PokedexQuotationMark bzw. gText_Lbs) bei x+44+3+Breite(Zahl)
--   Smaragd PrintMonInfo: alles bei x=144 statt 0x81; PrintMonHeight/Weight = gText_EmptyHeight/
--           -Weight bei 144, darueber PrintDecimalNum (fuehrende Nullen = SPACER, Komma)
--   Rubin/Saphir (pokeruby UNITS_METRIC): gDexText_UnknownHeight/-Weight bei Kachel 16, darueber
--           UnusedPrintDecimalNum mit CLEAR_TO (6 px je fuehrender Null), Komma
local function sk(x) return string.char(0xFC, 0x12, x) end   -- Stift absolut (relativ zum Textanfang)
local function cl(x) return string.char(0xFC, 0x11, x) end   -- Stift + x
local function ct(x) return string.char(0xFC, 0x13, x) end   -- Stift mindestens auf x

local function stellen(v)
  v = math.floor(tonumber(v) or 0)
  local a, b = math.floor(v / 1000), math.floor((v % 1000) / 100)
  local c, d = math.floor((v % 100) / 10), v % 10
  return a, b, c, d
end

local function frlgMetrisch()
  local okU, Units = pcall(require, "src.core.game3.pokedex_units")
  local okD, Data = pcall(require, "src.core.game3.pokedex_data")
  if not (okU and okD and type(Units) == "table" and type(Data) == "table") then return false end
  local RomText = require("src.core.game3.rom_text")
  local altMetric = Units.metric
  Units.metric = function(species)
    local r = altMetric(species)
    if r then return r end
    local ok, e = pcall(Data.getEntry, species)
    if ok and type(e) == "table" and e.heightDm then return { _de = true, dm = e.heightDm, hg = e.weightHg } end
    return nil
  end
  local function zahl(v)
    local a, b, c, d = stellen(v)
    local s = (a == 0 and " " or tostring(a)) .. ((b == 0 and a == 0) and " " or tostring(b))
    return s .. tostring(c) .. "," .. tostring(d)
  end
  local function text(num, key)
    -- Wert wird vom Port bei x+30 gezeichnet (Bezeichnung bei x); DE: Zahl bei x+44, Einheit +3
    return sk(14) .. num .. cl(3) .. RomText.plain(key)
  end
  local altH, altW, altUH, altUW = Units.height, Units.weight, Units.unknownHeight, Units.unknownWeight
  Units.height = function(e, ...) if type(e) == "table" and e._de then return text(zahl(e.dm), "gText_PokedexQuotationMark") end return altH(e, ...) end
  Units.weight = function(e, ...) if type(e) == "table" and e._de then return text(zahl(e.hg), "gText_Lbs") end return altW(e, ...) end
  Units.unknownHeight = function() return text("???,?", "gText_PokedexQuotationMark") end
  Units.unknownWeight = function() return text("???,?", "gText_Lbs") end
  return true
end

local function smaragdMetrisch()
  local ok, P = pcall(require, "src.ui.game3.rse.pokedex")
  if not ok or type(P) ~= "table" then return false end
  local RomText = require("src.core.game3.rom_text")
  local function zahl(v)
    local a, b, c, d = stellen(v)
    local s = (a == 0 and "{UNK_SPACER}" or tostring(a)) .. ((b == 0 and a == 0) and "{UNK_SPACER}" or tostring(b))
    return s .. tostring(c) .. "," .. tostring(d)
  end
  -- der Port zeichnet bei 0x81, DE bei 144 = 0x81 + 15
  P.heightText = function(h) return sk(15) .. RomText.plain("gText_EmptyHeight") .. sk(15) .. zahl(h) end
  P.weightText = function(w) return sk(15) .. RomText.plain("gText_EmptyWeight") .. sk(15) .. zahl(w) end
  local plain = RomText.plain
  RomText.plain = function(key, ...)
    local t = plain(key, ...)
    if (key == "gText_UnkHeight" or key == "gText_UnkWeight") and type(t) == "string" then return sk(15) .. t end
    return t
  end
  return true
end

local function rsMetrisch()
  local okP, P = pcall(require, "src.ui.game3.rse.pokedex")
  local okR, RsPolicy = pcall(require, "src.ui.game3.rs.pokedex_policy")
  if not (okP and okR and type(P) == "table" and type(RsPolicy) == "table") then return false end
  local RomText = require("src.core.game3.rom_text")
  local function text(v, key)
    local a, b, c, d = stellen(v)
    local versatz = 0
    local s = ""
    if a == 0 then versatz = 6 else s = s .. tostring(a) end
    if b == 0 and versatz ~= 0 then versatz = versatz + 6 else s = s .. tostring(b) end
    s = s .. tostring(c) .. "," .. tostring(d)
    -- Rest der Vorlage hinter "???,?" (Leerraum + Einheit) bleibt im DE-Spiel stehen
    local okT, vorlage = pcall(RomText.plain, key)
    local rest = okT and type(vorlage) == "string" and vorlage:match("^%?+,%?(.*)$") or ""
    return ct(versatz) .. s .. rest
  end
  P.heightText = function(h) return text(h, "gDexText_UnknownHeight") end
  RsPolicy.weightText = function(w) return text(w, "gDexText_UnknownWeight") end
  return true
end

-- pokedex.c (pokeruby): CATEGORY_LEFT EN 11 -> DE 16; die Kategorie wird rechtsbuendig an der Breite
-- von gDexText_UnknownPoke ausgerichtet (Port: Basis 88 = 11*8, y = 40) -> Basis 128.
local function rsDexKategorie()
  return hulle("src.ui.game3.rse.pokedex", "draw", function(alt)
    return function(...)
      local Font = require("src.ui.game3.frlg_font")
      local okR, ref = pcall(require("src.core.game3.rom_text").plain, "gDexText_UnknownPoke")
      local rechts = 88 + ((okR and type(ref) == "string") and Font.measure(ref) or 0)
      local draw = Font.draw
      Font.draw = function(text, x, y, ...)
        if y == 40 and type(x) == "number" and type(text) == "string"
          and (x == 88 or (x > 88 and x < 128 and math.abs(x + Font.measure(text) - rechts) < 1)) then
          x = x + 40
        end
        return draw(text, x, y, ...)
      end
      local ok, err = pcall(alt, ...)
      Font.draw = draw
      if not ok then error(err, 0) end
    end
  end)
end

-- battle_interface.c (pokeruby): CHAR_LV_SEPARATOR EN CHAR_COLON -> DE CHAR_PERIOD (Statusbalken)
local function rsLvTrenner()
  return hulle("src.core.game3.battle.healthbox", "draw", function(alt)
    local muster = string.char(0xFC, 0x11, 1, 0xFC, 0x14, 4) .. ":"
    local ersatz = string.char(0xFC, 0x11, 1, 0xFC, 0x14, 4) .. "."
    return function(...)
      local Font = require("src.ui.game3.frlg_font")
      local draw = Font.draw
      Font.draw = function(text, ...)
        if type(text) == "string" and text:sub(1, #muster) == muster then text = ersatz .. text:sub(#muster + 1) end
        return draw(text, ...)
      end
      local ok, err = pcall(alt, ...)
      Font.draw = draw
      if not ok then error(err, 0) end
    end
  end)
end

-- ---------------------------------------------------------------------------------------------
-- Namenseingabe: die DE-ROMs haben eine eigene Tastatur (Umlaute, andere Anordnung, mehr Spalten).
-- Gelesen wird zur Laufzeit aus der DE-ROM an den Rezeptadressen (R.tastatur, nur Zahlen):
--   rse  (FR/BG/Smaragd)  sKeyboardChars [3 Seiten][4 Zeilen][n] + sPageColumnCounts[3] + sPageColumnXPos[3][n]
--   rs   (Rubin/Saphir)   sKeyboardCharacters [3][4][20] + sKeyboardSymbolPositions [3][10];
--                         x = Position*8 + 24 (wie src/import/gba/rs/extract_naming.lua)
local function tastatur(ctx)
  local T, rom = ctx.R and ctx.R.tastatur, ctx.rom
  if type(T) ~= "table" or type(rom) ~= "string" then return false end
  local TextIR = require("src.core.game3.scripting.text_ir")
  local latin = require("src.ui.game3.frlg_font").LATIN_GLYPHS or {}
  local dialect = (ctx.ver == "ruby" or ctx.ver == "sapphire") and { dialect = "rs" } or nil
  local function u8(o) return rom:byte(o + 1) end
  local function zeichen(b)
    if b == 0x00 then return " " end
    if latin[b] then return latin[b] end
    local ok, s = pcall(function() return TextIR.toAscii(TextIR.decode({ b, 255 }, dialect)) end)
    return ok and s or " "
  end
  local kb = { chars = {}, columnCounts = {}, columnX = {} }
  local n = T.spalten
  if T.art == "rse" then
    for p = 0, 2 do
      local seite = {}
      for r = 0, 3 do
        local zeile = {}
        for c = 0, n - 1 do
          local b = u8(T.zeichen + (p * 4 + r) * n + c)
          zeile[c + 1] = { byte = b, char = zeichen(b) }
        end
        seite[r + 1] = zeile
      end
      kb.chars[p + 1] = seite
      kb.columnCounts[p + 1] = u8(T.anzahl + p)
      local xs = {}
      for c = 0, n - 1 do xs[c + 1] = u8(T.xpos + p * n + c) end
      kb.columnX[p + 1] = xs
    end
  elseif T.art == "rs" then
    kb.pageOrder = { "UPPER", "LOWER", "OTHERS" }
    for p = 0, 2 do
      local pos, gesehen, zahl = {}, {}, 0
      for c = 0, n - 1 do pos[c + 1] = u8(T.positionen + p * n + c) end
      -- letzte Position = Knopfspalte; Buchstabenspalten = verschiedene Positionen davor
      for c = 1, n - 1 do
        if not gesehen[pos[c]] then gesehen[pos[c]] = true; zahl = zahl + 1 end
      end
      kb.columnCounts[p + 1] = zahl
      local xs, seite = {}, {}
      for c = 1, zahl do xs[c] = pos[c] * 8 + 24 end
      for r = 0, 3 do
        local zeile = {}
        for c = 1, zahl do
          local b = u8(T.zeichen + (p * 4 + r) * T.zeilen_laenge + pos[c])
          zeile[c] = { byte = b, char = zeichen(b) }
        end
        seite[r + 1] = zeile
      end
      kb.chars[p + 1], kb.columnX[p + 1] = seite, xs
    end
  else
    return false
  end
  -- FR/BG haben kein Namens-Manifest mit Tastatur: der Port nimmt dann seine eingebauten EN-Seiten
  -- (st.pages = nil) -> nach Naming.open die DE-Seiten in den Zustand setzen
  local okN, Naming = pcall(require, "src.ui.game3.naming")
  if okN and type(Naming) == "table" and type(Naming.pagesFromKeyboard) == "function" then
    local seiten = Naming.pagesFromKeyboard(kb)
    if type(seiten) == "table" and #seiten == 3 then
      hulle("src.ui.game3.naming", "open", function(alt)
        return function(...)
          local st = alt(...)
          if type(st) == "table" and st.pages == nil and not st.rs then st.pages = seiten end
          return st
        end
      end)
    end
  end
  return hulle("src.ui.game3.naming", "pagesFromKeyboard", function(alt)
    return function(orig, ...)
      if type(orig) ~= "table" then return alt(orig, ...) end
      local neu = setmetatable({ chars = kb.chars, columnCounts = kb.columnCounts, columnX = kb.columnX,
        pageOrder = kb.pageOrder or orig.pageOrder }, { __index = orig })
      return alt(neu, ...)
    end
  end)
end

-- Smaragd PokeNav-Anrufliste (pokenav_list.c): DE druckt die Listeneintraege bei x=10 statt 8
-- (LoopedTask_PrintListItems, PrintCheckPageTrainerName, PrintMatchCallListTrainerName) und
-- Feldnamen/Kurzinfos der Detailseite bei x=4 statt 2 (PrintMatchCallFieldNames/-FlavorText).
local function navAnrufliste()
  local ok1 = hulle("src.ui.game3.rse.pokenav.match_call", "drawNameAndDesc", function(alt)
    return function(desc, name, x, ...) return alt(desc, name, (tonumber(x) or 0) + 2, ...) end
  end)
  local ok2 = hulle("src.ui.game3.rse.pokenav.match_call", "drawCheckPage", function(alt)
    return function(...)
      local Gfx = require("src.ui.game3.rse.pokenav.gfx")
      local text = Gfx.text
      Gfx.text = function(s, x, ...) return text(s, (tonumber(x) or 0) + 2, ...) end
      local ok, err = pcall(alt, ...)
      Gfx.text = text
      if not ok then error(err, 0) end
    end
  end)
  return ok1 and ok2
end

-- Smaragd PokeNav-Pokemonlisten (CreateSearchResultsList, CreateRibbonMonsList):
-- item_X 13 -> 12, windowWidth 17 -> 18
local function navMonListe()
  local ok, L = pcall(require, "src.ui.game3.rse.pokenav.mon_list")
  if not ok or type(L) ~= "table" or L.ITEM_X ~= 13 or L.WIDTH ~= 17 then return false end
  L.ITEM_X, L.WIDTH = 12, 18
  return true
end

-- Smaragd Kampfzonen-Ergebnisfenster (frontier_util.c Show*ResultsWindow, g3_code.py EN -> DE):
--   Turm 132 -> 125; Kuppel 121 -> 120, 112 -> 110; Palast 131 -> 125; Fabrik 158 -> 152, 64 -> 56;
--   Pyramide 8 -> 16, 64 -> 72, 111 -> 131 (Arena und Pike unveraendert)
local function zonenErgebnisse()
  return hulle("src.ui.game3.rse.frontier_records", "buildResults", function(alt)
    return function(sess, facility, ...)
      local win = alt(sess, facility, ...)
      local okF, Tr = pcall(require, "src.core.game3.rse.frontier.trainers")
      local F = okF and type(Tr) == "table" and Tr.FACILITY
      if type(win) ~= "table" or type(win.prints) ~= "table" or type(F) ~= "table" then return win end
      local karte
      if facility == F.TOWER then karte = { [132] = 125 }
      elseif facility == F.DOME then karte = { [121] = 120, [112] = 110 }
      elseif facility == F.PALACE then karte = { [131] = 125 }
      elseif facility == F.FACTORY then karte = { [158] = 152, [64] = 56 }
      elseif facility == F.PYRAMID then karte = { [8] = 16, [64] = 72, [111] = 131 } end
      if karte then
        for _, p in ipairs(win.prints) do
          if karte[p.x] then p.x = karte[p.x] end
        end
      end
      return win
    end
  end)
end

-- Smaragd Beerenetikett (berry_tag_screen.c PrintBerryDescription2): DE x = 5 statt 0
local function smaragdBeerenText()
  return hulle("src.ui.game3.rse.berry_tag", "draw", function(alt, Tag)
    return function(...)
      local okI, id = pcall(Tag.current)
      local okB, info = pcall(Tag.berryInfo, okI and id or 0)
      local d2 = okB and type(info) == "table" and info.description2
      local x0 = Tag.WIN and Tag.WIN.DESC and Tag.WIN.DESC[1] and Tag.WIN.DESC[1] * 8
      if type(d2) ~= "string" or d2 == "" or not x0 then return alt(...) end
      local Font = require("src.ui.game3.frlg_font")
      local draw = Font.draw
      Font.draw = function(text, x, ...)
        if text == d2 and x == x0 then x = x + 5 end
        return draw(text, x, ...)
      end
      local ok, err = pcall(alt, ...)
      Font.draw = draw
      if not ok then error(err, 0) end
    end
  end)
end

-- FR/BG Trainerpass Rueckseite (trainer_card.c PrintLinkBattleResultsOnCard): der Port zeichnet fest
-- "W:" (130) und "L:" (178); die ROM druckt gText_WinLossRatio ("..{CLEAR_TO}..") als eine Zeichenkette,
-- DE bei 132 statt 130, Siegzahl bei 148 statt 144 (g3_code.py), Niederlagen unveraendert bei 192.
local function frlgPassVerbindung()
  return hulle("src.ui.game3.trainer_card", "backTexts", function(alt)
    return function(...)
      local t = alt(...)
      if type(t) ~= "table" then return t end
      local ok, s = pcall(require("src.core.game3.rom_text").plain, "gText_WinLossRatio")
      if not ok or type(s) ~= "string" then return t end
      local out = {}
      for _, e in ipairs(t) do
        if e.id == "link_w" then e.text, e.x = s, e.x + 2; out[#out + 1] = e
        elseif e.id == "link_wins" then e.x = e.x + 4; out[#out + 1] = e
        elseif e.id ~= "link_l" then out[#out + 1] = e end
      end
      return out
    end
  end)
end

-- FR/BG Attacken-Neulerner (learn_move.c LoadMoveInfoUI): die ROM blittet Grafik-Symbole aus
-- gMenuInfoElements (BlitMenuInfoIcon, list_menu.c sMenuInfoIcons: Kachel-Versatz, 40x12), der Port
-- schreibt englische Woerter.  Stattdessen die Ausschnitte aus menu_info (DE-Grafik) zeichnen.
local function frlgNeulernerSymbole()
  local Strings = require("src.core.Strings")
  -- Wort -> Kachelversatz in der 128x128-Grafik (16 Kacheln je Zeile)
  local SYMBOL = { TYPE = 0xA8, POWER = 0xC0, ACCURACY = 0xC8, PP = 0xE0, EFFECT = 0xE8 }
  return hulle("src.ui.game3.move_relearner", "draw", function(alt)
    return function(...)
      local okS, SC = pcall(require, "src.ui.game3.summary_chrome")
      local img = okS and SC.menuInfoImage and SC.menuInfoImage()
      if not img then return alt(...) end
      local woerter = {}
      for wort, off in pairs(SYMBOL) do woerter[Strings(wort)] = off end
      local Font = require("src.ui.game3.frlg_font")
      local draw = Font.draw
      Font.draw = function(text, x, y, ...)
        local off = type(text) == "string" and woerter[text]
        if off and type(x) == "number" and type(y) == "number" then
          local sw, sh = img:getDimensions()
          local q = love.graphics.newQuad((off % 16) * 8, math.floor(off / 16) * 8, 40, 12, sw, sh)
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(img, q, x, y)
          return 40
        end
        return draw(text, x, y, ...)
      end
      local ok, err = pcall(alt, ...)
      Font.draw = draw
      if not ok then error(err, 0) end
    end
  end)
end

-- pokemon_size_record.c FormatMonSizeRecord: DE ohne Umrechnung in Zoll (UNITS_METRIC, Zentimeter);
-- Trennzeichen R/S "," (Literal im Code), FR/BG/Smaragd gText_DecimalPoint (DE-FR ",", DE-Smaragd ".")
local function groessenRekord(ver)
  return hulle("src.core.game3.pokemon_size_record", "formatMonSizeRecord", function(alt)
    return function(size)
      size = math.floor(tonumber(size) or 0)
      local sep = ","
      if ver ~= "ruby" and ver ~= "sapphire" then
        local ok, t = pcall(require("src.core.game3.rom_text").plain, "gText_DecimalPoint")
        if ok and type(t) == "string" and t ~= "" then sep = t end
      end
      return string.format("%d", math.floor(size / 10)) .. sep .. tostring(size % 10)
    end
  end)
end

-- field_specials.c DetermineCyclingRoadResults (Smaragd, R/S): CHAR_DEC_SEPARATOR DE ',' statt '.'
-- (g3_code.py: 173 -> 184 in beiden DE-ROMs)
local function radwegZeit()
  return hulle("src.core.game3.bike.specials_rse", "cyclingRoadResults", function(alt)
    return function(ctx, ...)
      local r, s1, s2 = alt(ctx, ...)
      if type(s2) == "string" then
        local neu = s2:gsub("^(%s*%d+)%.(%d%d)", "%1,%2", 1)
        if ctx and ctx.stringVars and ctx.stringVars[2] == s2 then ctx.stringVars[2] = neu end
        s2 = neu
      end
      return r, s1, s2
    end
  end)
end

return function(ctx)
  local log, ver = ctx.log, ctx.ver
  local n = 0
  if ver == "firered" or ver == "leafgreen" then
    if karteKopfzeile(log) then n = n + 1 end
    if frlgMetrisch() then n = n + 1 end
    if frlgPassVerbindung() then n = n + 1 end
    if frlgNeulernerSymbole() then n = n + 1 end
  end
  if ver == "emerald" then
    if kampfFenster() then n = n + 1 end
    if kampfJaNein() then n = n + 1 end
    if briefboxTitel() then n = n + 1 end
    if registerFenster() then n = n + 1 end
    if navInfoFenster() then n = n + 1 end
    if smaragdMetrisch() then n = n + 1 end
    if navAnrufliste() then n = n + 1 end
    if navMonListe() then n = n + 1 end
    if zonenErgebnisse() then n = n + 1 end
    if smaragdBeerenText() then n = n + 1 end
  end
  if ver == "ruby" or ver == "sapphire" then
    if rsOptionen() then n = n + 1 end
    if rsTeamMeldung() then n = n + 1 end
    if rsWeiterKasten() then n = n + 1 end
    if rsMemo() then n = n + 1 end
    if rsAttackenKappen() then n = n + 1 end
    if rsPassTitel() then n = n + 1 end
    if rsBeerenName() then n = n + 1 end
    if rsMetrisch() then n = n + 1 end
    if rsLvTrenner() then n = n + 1 end
    if rsDexKategorie() then n = n + 1 end
  end
  if groessenRekord(ver) then n = n + 1 end
  if ver == "emerald" or ver == "ruby" or ver == "sapphire" then
    if radwegZeit() then n = n + 1 end
  end
  local okT, errT = pcall(tastatur, ctx)
  if okT and errT then n = n + 1 elseif not okT then log:warn("Deutsch Gen 3: Tastatur: %s", tostring(errT)) end
  log:info("Deutsch Gen 3 (%s): Layout %d Anpassungen", tostring(ver), n)
end
