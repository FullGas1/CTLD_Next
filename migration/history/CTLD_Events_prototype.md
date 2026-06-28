--[[ -------------------------------------------------------

Spécifications logiques appliquées :Structure de données : Utilisation d'une table listeners où chaque clé est un identifiant d'événement (numérique pour DCS ou string pour l'application) pointant vers une liste indexée de fonctions.

Découplage : Le EventDispatcher est agnostique vis-à-vis de l'origine de l'événement. Il peut traiter des événements internes à l'application ou des événements injectés par le moteur world de DCS.
Complexité algorithmique :
  subscribe : $O(1)$ (insertion en fin de table).
  publish : $O(n)$ où $n$ est le nombre d'abonnés pour l'événement spécifique.

Interface API DCS : La méthode onEvent du DCSEventHandler respecte strictement la signature attendue par world.addEventHandler, permettant une redirection exhaustive des données brutes vers la logique orientée objet.

Dans une architecture orientée objet en Lua, la notion d'abonné (ou listener) désigne l'entité logicielle qui s'enregistre auprès d'un diffuseur (le EventDispatcher) pour être notifiée dès qu'une condition spécifique ou une action système survient.

Voici l'analyse technique exhaustive de cette composante :

1. Structure Technique de l'Abonné
Un abonné n'est pas nécessairement un objet complet, mais une référence vers une fonction de rappel (callback). Dans l'implémentation fournie précédemment, l'abonné est stocké sous forme de pointeur de fonction dans une table indexée.

Identifiant d'événement : La clé (ex: 15 pour S_EVENT_BIRTH ou "OnCargoDropped").

Référence de rappel : L'adresse de la fonction à exécuter.

Portée (Scope) : L'abonné s'exécute généralement dans le contexte global, sauf si une fermeture (closure) est utilisée pour capturer l'instance d'un objet (self).

2. Mécanisme d'Enregistrement (Subscription)
L'abonnement est une opération d'ajout dans une structure de données de type Multi-Map.

Liaison Tardive (Late Binding) : L'abonné n'a pas besoin de connaître l'émetteur de l'événement, seulement le nom de l'événement. Cela permet un découplage total entre les modules (ex: le module de transport de troupes ne connaît pas le module de gestion d'interface UI).

Conteneur d'Abonnés

Cycle de Vie de la Notification
Lorsqu'un événement est publié, le dispatcher itère sur la liste des abonnés :

Déclenchement : Le moteur DCS ou une classe logique appelle publish(id, data).

Lookup : Recherche de la table d'abonnés associée à id.

Itération : Parcours séquentiel de la table.

Exécution Synchronisée : Chaque fonction d'abonné est appelée l'une après l'autre.

Note technique : En Lua DCS, l'exécution est bloquante. Si un abonné contient une boucle lourde, il ralentira la distribution pour tous les abonnés suivants.

Contraintes d'Intégrité
Unicité : Sans vérification explicite, un même abonné (la même fonction) peut être enregistré plusieurs fois pour le même événement, provoquant des exécutions redondantes.

Persistance : Un abonné reste actif tant qu'il n'est pas explicitement supprimé (unsubscribe) ou que le EventDispatcher n'est pas détruit. En DCS, cela est critique pour éviter des fuites de mémoire sur des scripts chargés à répétition.


2. Version consolidée de la classe EventDispatcher
Cette version inclut la gestion de la suppression et assure l'étanchéité de la logique de distribution.
------------------------------------------------------------- ]]--



-- ============================================================================
-- CLASSE : EventDispatcher
-- OBJET : Moteur de distribution d'événements (Pattern Observer)
-- ============================================================================

EventDispatcher = {}
EventDispatcher.__index = EventDispatcher

function EventDispatcher:new()
    local instance = setmetatable({}, self)
    instance.listeners = {} 
    return instance
end

function EventDispatcher:subscribe(eventName, callback)
    if type(callback) ~= "function" then return end
    if not self.listeners[eventName] then
        self.listeners[eventName] = {}
    end
    table.insert(self.listeners[eventName], callback)
end

function EventDispatcher:unsubscribe(eventName, callback)
    local subscribers = self.listeners[eventName]
    if not subscribers then return end
    for i = #subscribers, 1, -1 do
        if subscribers[i] == callback then
            table.remove(subscribers, i)
        end
    end
end

function EventDispatcher:unsubscribeAll(eventName)
    self.listeners[eventName] = nil
end

function EventDispatcher:publish(eventName, data)
    local subscribers = self.listeners[eventName]
    if not subscribers or #subscribers == 0 then return end
    
    local dispatchList = {}
    for i, cb in ipairs(subscribers) do -- load in dispatchList each subscriber callback function to be executed
        dispatchList[i] = cb 
    end

    for i = 1, #dispatchList do
        dispatchList[i](data)		-- execute subscriber callback function
    end
end

-- ============================================================================
-- CLASSE : DCSEventHandler
-- OBJET : Adaptateur API DCS World (world.addEventHandler)
-- ============================================================================

DCSEventHandler = {}
DCSEventHandler.__index = DCSEventHandler

function DCSEventHandler:new(dispatcher)
    local instance = setmetatable({}, self)
    instance.dispatcher = dispatcher
    return instance
end

function DCSEventHandler:onEvent(event)
    if not event or not event.id then return end
    self.dispatcher:publish(event.id, event)
end

-- ============================================================================
-- CLASSE MÉTIER : RadarSystem
-- OBJET : Gestionnaire de détection d'unités avec gestion de cycle de vie
-- ============================================================================

RadarSystem = {}
RadarSystem.__index = RadarSystem

--- Instancie un nouveau système radar
-- @param dispatcher table Instance de EventDispatcher
-- @param frequency number Fréquence de mise à jour (simulation)
function RadarSystem:new(dispatcher, frequency)
    local instance = setmetatable({}, self)
    instance.dispatcher = dispatcher
    instance.frequency = frequency
    instance.contacts = {} -- Table des unités suivies
    
    -- IDENTIFICATION DE L'ABONNÉ :
    -- On crée une fermeture (closure) pour capturer 'self' (l'instance)
    -- On stocke cette référence dans un attribut pour permettre le désabonnement.
    instance._onBirthRef = function(eventData) 
        instance:onUnitBirth(eventData) 
    end
    
    -- ABONNEMENT :
    -- 15 correspond à l'énumération world.event.S_EVENT_BIRTH
    instance.dispatcher:subscribe(15, instance._onBirthRef)
    
    env.info("RADAR_SYSTEM: Instance créée et abonnée au flux DCS.")
    return instance
end

--- Logique de traitement lors de l'apparition d'une unité
-- @param event table Données de l'événement DCS
function RadarSystem:onUnitBirth(event)
    if event.initiator then
        local unitName = event.initiator:getName()
        local unitId = event.initiator:getID()
        
        -- Mise à jour de l'état interne
        self.contacts[unitId] = {
            name = unitName,
            timeDetected = timer.getTime()
        }
        
        env.info("RADAR_SYSTEM: Contact enregistré -> " .. unitName .. " (ID: " .. unitId .. ")")
    end
end

--- Procédure de destruction du système
-- Libère les ressources et coupe les liaisons d'événements
function RadarSystem:destroy()
    -- DÉSINCRIPTION IMPÉRATIVE :
    -- Empêche le dispatcher d'appeler une méthode sur une instance censée être détruite.
    -- Sans cela, 'self:onUnitBirth' serait appelé, provoquant une erreur (null reference).
    self.dispatcher:unsubscribe(15, self._onBirthRef)
    
    self.contacts = nil
    env.info("RADAR_SYSTEM: Instance détruite et désabonnée.")
end

-- ============================================================================
-- INITIALISATION GLOBALE DU PROJET
-- ============================================================================

-- 1. Coeur du système
local mainDispatcher = EventDispatcher:new()
local dcsBridge = DCSEventHandler:new(mainDispatcher)
world.addEventHandler(dcsBridge)

-- 2. Instanciation du module métier
local myRadar = RadarSystem:new(mainDispatcher, 1.0)

-- 3. Exemple de fin de mission / suppression du module
-- myRadar:destroy()

-- ============================================================================
--[[---------exemple-----------------------------------------------------
3. Analyse logique du cycle de vie de l'abonné
L'abonné traverse trois états logiques :

Enregistrement (Subscribed) : La fonction est référencée dans la structure listeners. Elle consomme une petite quantité de mémoire (le pointeur).

Actif (Triggered) : Lors de l'appel à publish, le code de l'abonné est chargé dans la pile Lua et exécuté avec les paramètres data.

Libération (Unsubscribed/Garbage Collected) :

Si unsubscribe est appelé : la référence est supprimée de la table. La fonction devient éligible au Garbage Collector de Lua (si elle n'est référencée nulle part ailleurs).

Risque technique : Si vous utilisez des fonctions anonymes (function(d) ... end) lors de l'abonnement sans stocker leur référence dans une variable, vous ne pourrez jamais appeler unsubscribe sur cet abonné précis (car vous ne pourrez pas fournir la référence originale).

4. Application à une classe métier (Exemple exhaustif)

Cette structure garantit qu'aucune exécution résiduelle ne survienne après la destruction d'un composant de l'application, respectant ainsi les contraintes de performance de l'environnement DCS.
---------------------------------------------------------------------- ]]--

------------------------------------------------------------------------