-- diag_beacon_ogg_test.lua — joue beacon.ogg en audio pur (outSound), sans radio
-- Si le son est entendu → le fichier .ogg est bien dans la mission
-- Si silence → beacon.ogg absent de la mission (à ajouter dans Mission > Sounds)
trigger.action.outSound("l10n/DEFAULT/beacon.ogg")
ctld.utils.log("INFO", "[ogg_test] played beacon.ogg via outSound")
return "beacon.ogg played"
