-- Disable autoOrbit loop so drone keeps assigned Mission route
CTLDConfig.get().settings["enableAutoOrbitingFlyingJtacOnTarget"] = false
trigger.action.outText("[debug] jtacAutoOrbit = FALSE — orbit loop disabled", 10)
return "jtacAutoOrbit disabled"
