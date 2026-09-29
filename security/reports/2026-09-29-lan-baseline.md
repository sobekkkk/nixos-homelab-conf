# Baseline LAN non destructif — 29 septembre 2026

Ce rapport complète la revue white-box et la remédiation. Les fichiers Nmap
bruts restent hors du dépôt ; ce document ne conserve que leur synthèse
nécessaire à la décision.

## Périmètre et méthode

| Élément | Valeur |
| --- | --- |
| Origine | Poste Windows d'administration autorisé |
| Cible | `192.168.1.69` uniquement |
| Outil | Nmap 7.991 |
| Date | 2026-09-29, 23:52–23:53 CEST |
| Ports testés | TCP 22, 443 et 9443 uniquement |
| Tests | Découverte de version, bannière SSH, algorithmes SSH et inspection TLS passive |

Aucun scan de sous-réseau, test d'authentification, OAST, fuzzing, exploitation
ou tentative de connexion n'a été effectué.

## Résultats observés

| Port | État | Évaluation |
| --- | --- | --- |
| 22/TCP | ouvert, OpenSSH 10.5 | Conforme à l'administration SSH attendue. Les algorithmes observés sont modernes ; aucun algorithme faible n'a été relevé par le baseline. |
| 443/TCP | filtré, sans réponse | Conforme : Caddy/Uptime Kuma ne sont pas encore déployés. |
| 9443/TCP | ouvert, HTTPS Portainer | Conforme à l'exception temporaire de migration, mais le certificat est encore auto-signé et ne porte pas l'identité LAN du serveur. |

L’inspection TLS de 9443 n'a relevé que TLS 1.2 et TLS 1.3 avec un niveau de
chiffrement évalué `A` par Nmap. Cela ne résout pas F-05 : le problème restant
est l'authentification de l'identité du serveur, pas la force cryptographique
des suites TLS.

## Conclusion du baseline

Aucune nouvelle exposition n'a été observée dans le périmètre autorisé. Le
baseline reteste positivement l'exposition SSH attendue et confirme que 443
n'est pas ouvert prématurément. Il confirme aussi les limites déjà connues :
Portainer reste directement disponible sur 9443 tant que Caddy n'est pas
déployé, et AppArmor reste sans profil chargé.

La fermeture de F-04/F-05 exige le déploiement authentifié du stack Portainer,
l'installation contrôlée de l'autorité Caddy sur les clients de confiance, puis
le retrait de 9443. La fermeture de F-02 exige des profils AppArmor propres aux
services réellement exécutés, testés avant leur passage en enforcement.
