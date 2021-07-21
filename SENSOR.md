# Sensor commands

a: nom du capteur

b: lecture de toute la carte SD

c: activer l'envoi des données temps réel vers BLE (au démarrage live_BLE = false)

d: désactiver l'envoi des données temps réel vers BLE

e: supprimer données carte SD

f: rafraichir l'horloge interne avec le GPS (si on capte le GPS)

g: activer l'envoi des données temps réel vers liaison série (PC) (au démarrage live_PC = true)

h: désactiver l'envoi des données temps réel vers liaison série (PC)

i: synchroniser l'horloge interne avec une trame de données -> sscanf(cmd.c_str(), "i%d;%d;%d;%d;%d;%d", &Hour, &Minute, &Second, &Day, &Month, &Year);