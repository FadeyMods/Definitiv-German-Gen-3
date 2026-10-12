-- Alle Texte, die der Port ueber ihren Schluessel holt (Label oder "g3:<EN-Adresse>"): mod.content.text.
-- Der Text wird ab der DE-Adresse mit dem Decoder des Ports gelesen (Kampftexte mit Kampf-Optionen).
return function(W)
  local mod, R, log, ver = W.mod, W.R, W.log, W.ver
  local isBattle = {}
  for _, k in ipairs(R.battle or {}) do isBattle[k] = true end
  local n, failed, firstErr = 0, 0, nil
  for key, off in pairs(R.text or {}) do
    local ok, err = pcall(function()
      local ir = assert(W.decodeAt(off, isBattle[key]), "kein Textende")
      mod.content.text:override(key, ir)
    end)
    if ok then n = n + 1 else
      failed = failed + 1
      firstErr = firstErr or (tostring(key) .. ": " .. tostring(err))
    end
  end
  log:info("Deutsch Gen 3 (%s): text %d uebernommen, %d Fehler%s", ver, n, failed,
    firstErr and (" (" .. firstErr .. ")") or "")

  -- FRLG-Einleitung (src/ui/game3/new_game_scene.lua, oakPrint): der Port macht aus \l (Zeile hochrollen) ein
  -- \n, eine dritte Zeile ragt dann unter den Textkasten ("ihnen aus.").  Die deutschen Texte nutzen \l, die
  -- englischen hier nicht.  Wie in der ROM: nach \l steht die letzte Zeile oben, die neue darunter -> \p + Zeile.
  pcall(function()
    local Scene = require("src.ui.game3.new_game_scene")
    local RomText = require("src.core.game3.rom_text")
    if type(Scene.oakPrint) ~= "function" or Scene._deutschRollen then return end
    Scene._deutschRollen = true
    local function rollen(t)
      if type(t) ~= "string" or not t:find("\\l", 1, true) then return t end
      local out, zeile, i = {}, {}, 1
      while i <= #t do
        local c, d = t:sub(i, i), t:sub(i + 1, i + 1)
        if c == "\\" and d == "l" then
          out[#out + 1] = "\\p" .. table.concat(zeile) .. "\n"; zeile = {}; i = i + 2
        elseif c == "\\" and d == "p" then
          out[#out + 1] = "\\p"; zeile = {}; i = i + 2
        elseif c == "\n" then
          out[#out + 1] = "\n"; zeile = {}; i = i + 1
        else
          out[#out + 1] = c; zeile[#zeile + 1] = c; i = i + 1
        end
      end
      return table.concat(out)
    end
    local alt = Scene.oakPrint
    Scene.oakPrint = function(self, ...)
      local ascii = RomText.ascii
      RomText.ascii = function(...) return rollen(ascii(...)) end
      local ok, e = pcall(alt, self, ...)
      RomText.ascii = ascii
      if not ok then error(e, 0) end
    end
  end)
end
