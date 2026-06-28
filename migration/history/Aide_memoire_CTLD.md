-- Aide mémoire Evolution CTLD


-------------- Sessions --------------
. [2026-04-30] GAP-1 fix COMPLET — refresh Load+Pack menus après unpack sans re-entry F10
   Fait : _spawnUnpacked → refreshLoadSectionForUnit + refreshPackSectionForUnit(playerName)
   Commit : 63febd8 fix(menu): refresh Load+Pack menus after unpack (GAP-1 complete)
   Validé : F-124 1/1 PASS live (UH-1H)
   Prochaine session : vérifier si docs/missionmaker_guide.md besoin mise à jour (non fait)

-------------- Crates --------------
. Association d'une scene à une crate
. Ajout methode autoUnpack (gérer spawn auto de group à partir d'1 ou plusieurs crates, (ex: arrivée au sol de crate parachutées))
. détecter le chargement d'une crate CTLD via fct load standard DCS (Uh, CH47, C130,...) (réflechir à meilleurs solution car pas d'event généré lors du 'Load': par proximité verticale/horizontale caisse/appareil getPoint(), par comparaison de vitesse caisse appareil (inair() getVelocity(). surveiller mouvement de caisse et rechercher quel appareil à le mouvement le + proche ou similaire (vitesse, altitude) pour associer caisse à appareil.
. détecter Unload ou parachutage d'un caisse CTLD par fct standard DCS.
.. une caisse précemment loadée, ne suit plus la même vitesse/altitude que son porteur. Ou détecter que la caisse est au sol immobile (plus dans la carlingue delta altitude/landAlti.
.. voir si un moyen de détecter le cas particulier d'un parachutage (event Birth parachute, Alti caisse précement loadée décroissante et différente de l'alti porteur (qui s'éloigne), de même éloignement de leur position (x,z) relatives indique que porteur s'éloigne de caisse.
. Si parachutage en cours détecté, voir comment le suivre durant la descente, et générer un pseudoEvent indiquant le posé de la caisse parachutée.
. Voir si possible de gérer un système d'Events propre à CTLD, permettant de signaler:
.. spawn de caisses nouvelles
.. Load de caisse (via CTLD ou Load standard DCS)
.. Unload de caisse (via CTLD ou unload standard DCS)
.. pack de caisse   (manuel ou automatique)
.. unpack de caisse (manuel ou automatique)
.. pack de caisse (manuel ou automatique)
-------------- Scenes --------------
. ajout d'un condition lua predicate permettant de déclencher ou non la réalisation d'une étape d'une scene (ex: ne spawner un objet que si au moins 1 infanterie est à moins de 20m) 