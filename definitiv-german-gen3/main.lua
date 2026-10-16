-- Definitiv German Gen 3  (Rubin, Saphir, Smaragd, Feuerrot, Blattgrün)
--
-- Dieser Mod enthaelt KEINE Texte oder Grafiken der Spiele, auch keine englischen Texte als Suchschluessel.
-- Er bringt nur Rezepte mit (Adressen in der deutschen ROM; Texte des Ports nur als Pruefsumme, siehe
-- werkzeug.lua) und liest beim Start die deutsche ROM der laufenden Edition, die du im Launcher importiert
-- hast -- immer genau das Gegenstueck.
--
-- Aufbau (jeder Baustein hat sein eigenes Rezept rezept_<edition>_<baustein>.lua):
--   werkzeug.lua    Edition, deutsche ROM, alle Rezepte, Dekodieren mit den deutschen Zusatzzeichen
--   dialoge.lua     alle Texte, die der Port ueber ihren Schluessel holt     (mod.content.text)
--   daten.lua       Namen (Pokemon, Attacken, Faehigkeiten, Items), Datendateien (Beschreibungen,
--                   Pokedex, Beeren, Kampfzone/Pyramide/Lehrling mit eingebettetem Text), Fundort-Memo
--   port_texte.lua  feste Texte des Ports und Easy-Chat-Woerter              (mod.content.strings)
--   layout.lua      Kaesten, Positionen, Masse, Einheiten, Tastatur wie in der DE-ROM (install(ctx))
--   grafik.lua      Grafiken mit Schrift: Extraktoren des Ports auf der DE-ROM
--   port_extras.lua Port-Zusaetze ohne ROM-Gegenstueck (MODS-Verwaltung, Optionen, Link-Menue)
--   port_extras_daten.lua  deutsche Texte dazu, ERZEUGT von Test/werkzeug/port_extras_quelle.py
return function(mod)
  local quelle = mod:read("werkzeug.lua")
  local chunk, err = (loadstring or load)(quelle or "", "@werkzeug.lua")
  if not chunk then
    mod.log:warn("Deutsch Gen 3: werkzeug.lua fehlerhaft: %s", tostring(err))
    return
  end
  local W = chunk()(mod)
  if not W then return end
  for _, baustein in ipairs({ "dialoge", "daten", "port_texte", "layout", "grafik", "port_extras" }) do
    W.baustein(baustein)
  end
end
