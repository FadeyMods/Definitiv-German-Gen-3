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
end
