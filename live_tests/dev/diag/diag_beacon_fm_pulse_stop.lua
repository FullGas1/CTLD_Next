-- diag_beacon_fm_pulse_stop.lua — arrête la transmission FM pulsée du test
trigger.action.stopRadioTransmission("CTLD_FM_PULSE_TEST")
ctld.utils.log("INFO", "[FM_PULSE] stopped by diag_beacon_fm_pulse_stop")
trigger.action.outText("[FM_PULSE] Transmission FM pulsée arrêtée", 5)
return "FM pulse stopped"
