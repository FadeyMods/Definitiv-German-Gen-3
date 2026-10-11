-- 📀🇩🇪 Definitiv German 💬✅ Gen 3  (Rubin, Saphir, Smaragd, Feuerrot, Blattgrün)
--
-- Dieser Mod enthaelt KEINE Texte oder Grafiken der Spiele.  Er bringt nur Rezepte mit
-- (Textschluessel des Ports -> Adresse in der deutschen ROM) und liest beim Start die deutsche ROM
-- der laufenden Edition, die du im Launcher importiert hast -- immer genau das Gegenstueck.  Die Texte
-- werden mit dem Decoder des Ports (TextIR.decode) umgewandelt -- genau wie beim Import der EN-ROM.
--
-- Aufbau (jeder Baustein hat sein eigenes Rezept rezept_<edition>_<baustein>.lua):
--   werkzeug.lua    Edition, deutsche ROM, alle Rezepte, Dekodieren mit den deutschen Zusatzzeichen
--   dialoge.lua     alle Texte, die der Port ueber ihren Schluessel holt     (mod.content.text)
--   daten.lua       Namen (Pokemon, Attacken, Faehigkeiten, Items), Datendateien (Beschreibungen,
--                   Pokedex, Beeren, Kampfzone/Pyramide/Lehrling mit eingebettetem Text), Fundort-Memo
--   port_texte.lua  feste Texte des Ports und Easy-Chat-Woerter              (mod.content.strings)
--   layout.lua      Kaesten, Positionen, Masse, Einheiten, Tastatur wie in der DE-ROM (install(ctx))
--   grafik.lua      Grafiken mit Schrift: Extraktoren des Ports auf der DE-ROM
return function(mod)
  local quelle = mod:read("werkzeug.lua")
  local chunk, err = (loadstring or load)(quelle or "", "@werkzeug.lua")
  if not chunk then
    mod.log:warn("Deutsch Gen 3: werkzeug.lua fehlerhaft: %s", tostring(err))
    return
  end
  local W = chunk()(mod)
  if not W then return end
  for _, baustein in ipairs({ "dialoge", "daten", "port_texte", "layout", "grafik" }) do
    W.baustein(baustein)
  end
end
