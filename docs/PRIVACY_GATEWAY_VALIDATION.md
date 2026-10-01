# Recette de la passerelle — 2026-10-01

## Résultats observés, pas une certification de sécurité

| Contrôle | Résultat |
| --- | --- |
| Compilation invitée + hôte, flake pure | Réussite |
| SSH bootstrap hôte | Loopback 2222 uniquement, identité comparée à la console |
| Sortie IPv4 invitée | API Mullvad : exit IP true, ch-zrh-wg-402, Zurich |
| HTTPS IPv6 invité | example.com, HTTP 200, route WireGuard |
| DNS invité | AdGuard loopback : NOERROR pour A et AAAA |
| VPN coupé : TCP IPv4 / IPv6 avec résolution forcée | Bloqué, curl 28 / 7 |
| VPN coupé : DNS direct 10.64.0.1 | Timeout, dig 9 |
| Retour VPN après test | Mullvad exit IP true à nouveau |
| Tailscale invité | Running, Online, health vide |
| SSH et DNS Windows via Tailscale invité | Réussite après correction des priorités |
| SSH / tailscaled / VM hôte | Services actifs après les tests |

Le script reproductible est `scripts/privacy-gateway/test-kill-switch.sh`.
Il tourne dans l'invité et rétablit WireGuard par trap ; jamais sur l'hôte.
Avec PowerShell/stdin SSH, normaliser les CR avant `bash -s`.
Le test final a terminé avec code 0, sans modifier le DNS Windows.

## Défauts de première activation et corrections

- qemu-vm remplaçait fileSystems, supprimant le montage de credential : mount
  unit explicite. Le montage transitoire a permis la recette sans lire la clé.
- Enregistrement Nix impossible sur `/nix/store/.links` read-only : désactiver
  Nix dans l'appliance, reconstruite sur l'hôte.
- Routage wg-quick avant les pairs Tailscale : table WireGuard 51820 et
  priorités explicites 5000 (pairs table 52), 5010 (main hors route par défaut),
  5020 (WireGuard sauf son propre fwmark). Le transport extérieur Tailscale
  reste dans Mullvad ; pas de bypass physique autorisé.

Les sources corrigées compilent. Une nouvelle activation `test` et le contrôle
du démarrage autonome restent requis : les correctifs runtime ne les prouvent pas.

## Restant avant livraison

- Vérifier le redémarrage autonome du montage et du tunnel.
- Sortie approuvée dans Tailscale (vérifiée depuis Windows et l'invité le
  2026-10-01 : ExitNodeOption true, routes 0.0.0.0/0 et ::/0). Tester un
  client qui l'utilise reste nécessaire.
- Configurer et tester le DNS client, IPv6, panne de passerelle et déconnexion.
- Tester la politique Windows, documenter les limites Android/TV non gérés.
- Persister et commit/push uniquement après la recette et la doc finales.

Aucun contenu de clé privée, historique DNS ou dump WireGuard contenant une
clé n'a été utilisé comme preuve. Pas de garantie d'anonymat ou d'HA.

## Deuxième activation test

La génération hôte `6qx1i7z4scap75mirgkidcnfi21szknq` a démarré les quatre
services invités et le montage de credential sans unité en échec. Le marquage
WireGuard était néanmoins absent : `%i` dans le script postUp généré par NixOS
n'est pas substitué par wg-quick. Cela causait une récursion du transport et
bloquait DNS/Internet. Le nom explicite `wg-mullvad` remplace `%i` dans les
sources ; le marquage runtime 51820 rétablit DNS AdGuard, sortie Mullvad IPv4,
HTTPS IPv6 et Tailscale Running/Online sans alerte. Une nouvelle activation
test doit encore confirmer le correctif déclaratif au démarrage.

## Troisième activation test : démarrage autonome validé

Génération hôte `1fdmp6wl2fhrnzjyr7cj45p7z49w2njd`, vérifiée après
redémarrage de la VM par `nixos-rebuild test` : quatre services invités actifs,
aucune unité en échec, fwmark `0xca6c` (51820) présent sans intervention.
AdGuard répond depuis la VM et depuis Windows via `100.116.220.6` ; l'API
Mullvad confirme la sortie suisse et HTTPS IPv6 retourne 200. Tailscale
annonce l'exit node approuvé/en ligne. SSH, tailscaled et superviseur VM hôte
restent actifs. Le PC Windows ne sélectionne encore aucun exit node : le
parcours Internet/DNS d'un client reste à tester avant persistance finale.

## Premier test client Windows : correction DNS

Exit node sélectionné temporairement, puis désélectionné en fin de test.
HTTPS vers une IP forcée retournait 200, mais DNS échouait. Les logs
tailscaled indiquaient l'absence de /etc/resolv.conf. AdGuard lui-même répondait
correctement. Après installation runtime du fichier nameserver 127.0.0.1,
Windows résout Google et l'API Mullvad confirme 138.199.6.212 avec exit IP true.
Le fichier est désormais déclaré par environment.etc ; sa présence au prochain
démarrage doit être confirmée après une activation test.

## Quatrième activation test : DNS persistant et client validés

Génération hôte `2fb1icc3qiz0kbf04m6m7w84nilh8ks8` : resolv.conf vers
127.0.0.1 présent au démarrage, fwmark 51820 présent et aucune unité invitée
en échec. Test Windows avec exit node temporairement sélectionné : résolution
Google A/AAAA, API Mullvad exit IP true (138.199.6.212), HTTPS Google IPv4
HTTP 200 et example.com IPv6 HTTP 200. Validation TLS Windows conservée :
l'erreur de révocation précédente ne se reproduit pas dans ce test.
Réglage exit node Windows initial restauré après la recette. Ces résultats
ne prouvent pas encore le comportement client lors d'une panne de VM/VPN,
ni les réglages DNS privé/DoH des appareils Android/TV et navigateurs.

## Correction de débit et test de coupure client

Le 2026-10-01, téléchargements HTTPS Cloudflare __down, sortie jetée, volumes
limités : 2 Mo pour comparaison avant/après, puis 8 Mo IPv4 et IPv6. Windows
sélectionne temporairement privacy-gateway et revient ensuite sans exit node.

| Mesure | Résultat |
| --- | --- |
| VM Mullvad, avant correction, 2 Mo | 38,31 Mbit/s |
| Client avant, 2 Mo demandés | 1 442 944 octets en 20 s, timeout, ~0,58 Mbit/s |
| Fragments IPv4 pendant ce test client | 14 998 → 18 862 |
| Client après MTU 1420, 2 Mo IPv4 / IPv6 | 4,46 / 7,39 Mbit/s |
| Client après, 8 Mo IPv4 / IPv6 | 10,79 / 13,62 Mbit/s |
| Fragments IPv4 après tests corrigés | compteur stable à 18 862 |
| Upload hôte / VM Mullvad, 2 Mo de zéros | 61,36 / 33,76 Mbit/s |
| VPN coupé, client TCP IPv4 / IPv6 avec résolution forcée | timeout curl 28 / 28 |
| Retour VPN | API Mullvad exit IP true, aucune unité invitée en échec |

Cause étayée : fragmentation du transport Tailscale par l'interface Mullvad
à MTU 1280. Correction runtime 1420 validée, équivalent déclaratif compilé
dans la génération hôte `dw1g960133js7dar8lck17irv13nvxnj` (pas encore activée).
Pas de modification du pare-feu ni de sortie Tailscale directe. MTU 1420
doit être revalidée si l'uplink ou le serveur VPN changent. Les mesures courtes
incluent établissement TLS et montée de fenêtre TCP ; serveurs/instants varient.
Pas de promesse d'absence de fuite exhaustive ni de bypass de tout blocage.

## Activation de la correction MTU confirmée

L'opérateur a activé `dw1g960133js7dar8lck17irv13nvxnj` en mode test.
Contrôle SSH post-activation : wg-mullvad MTU 1420, fwmark 51820,
resolv.conf nameserver 127.0.0.1, aucune unité invitée en échec, DNS A,
Mullvad exit IP true et HTTPS IPv6 HTTP 200. Services hôte SSH, Tailscale
et VM actifs. Au contrôle avant publication, la génération persistée reste
`n373nn2mxdnaf1gfijrk42cfy2k9v34k` : switch encore requis.

## Persistance après switch propriétaire

Après annonce du switch par l'opérateur, contrôle SSH du 2026-10-01 :
/run/current-system et /nix/var/nix/profiles/system résolvent tous deux vers
`dw1g960133js7dar8lck17irv13nvxnj`. SSH/Tailscale/VM hôte actifs ; invité sans
unité en échec, MTU 1420 et resolver AdGuard présents, API Mullvad exit IP true.
Pas de reboot hôte exécuté ou revendiqué. Les preuves précédentes décrivent
chronologiquement les étapes avant cette persistance.
