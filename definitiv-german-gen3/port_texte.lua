-- Feste Texte des Ports (mod.content.strings, Schluessel = englischer Text im Port-Code) aus der DE-ROM,
-- dazu die Easy-Chat-Woerter und -Gruppen ("easyChat.word[<id>]", "easyChat.group[<g>]",
-- src/core/game3/easy_chat_text.lua) und Ortsnamen.
return function(W)
  local mod, R, log, ver = W.mod, W.R, W.log, W.ver
  local nS, fS, firstErr = 0, 0, nil
  for lit, teile in pairs(R.strings or {}) do
    local ok, e = pcall(function() mod.content.strings:override(lit, W.teile(teile)) end)
    if ok then nS = nS + 1 else
      fS = fS + 1
      firstErr = firstErr or (tostring(lit) .. ": " .. tostring(e))
    end
  end
  log:info("Deutsch Gen 3 (%s): strings %d uebernommen, %d Fehler%s", ver, nS, fS,
    firstErr and (" (" .. firstErr .. ")") or "")
end
