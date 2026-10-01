# État, preuves et limites

Revue documentaire : 30 septembre 2026. Sources figées lues :
infrastructure main 3de2ac3 ; applications main 768f95f.
Ce dossier est une revue de sources et de preuves antérieures, pas un nouveau
pentest ni une collecte privilégiée du serveur.

## 1. État des briques

Chantier NetV du 2026-10-01 : configurations hôte, VM, application et proxy
préparées sur `codex/netv`. Les trois Compose passent la validation de modèle.
La construction NixOS hôte/invité a réussi ; aucune activation NetV, recette
de coupure, mesure de débit ou lecture IPTV n'est encore attestée. Voir
[le runbook](NETV.md). La génération en production n'est pas remplacée.

Suite à l'activation test par le propriétaire : génération active
`jf346kvz0lfc0x2wy4rvaq0w7kcxd5d3`, interfaces TAP invitées et route source hôte
observées ; sortie Mullvad et DNS AdGuard de la VM confirmés par SSH. La stack
NetV, les tests de coupure applicatifs et la persistance restent à valider.

Ajout runtime du 2026-10-01 : [recette passerelle](PRIVACY_GATEWAY_VALIDATION.md).
Base hôte avant chantier : 96c7f9a. Génération active testée :
`dw1g960133js7dar8lck17irv13nvxnj`. Après switch propriétaire, la génération
persistée est identique (contrôle SSH du 2026-10-01). Reboot hôte non testé.
Tailscale exit approuvé, DNS AdGuard, IPv4/IPv6 Mullvad, boot VM et tests TCP
VPN-down depuis Windows vérifiés. Android/TV, panne VM complète et verrouillage
client obligatoire restent non attestés. Cette recette n'est pas un pentest.

| Brique | Déclaré / observé | Reste à attester |
| --- | --- | --- |
| LUKS, Secure Boot, TPM PIN | Déclaré ; boots réussis montrés par opérateur | État boot/masque effectif lors de chaque changement |
| SSH / sudo | Déclaré ; contrôles SSH corrélés dans revue agent du 30/09 | Pas une garantie contre toute vulnérabilité |
| Docker guard | Déclarée ; présence IPv4/IPv6 observée dans revue agent | Exposition réellement vue depuis Windows |
| Tailscale / Serve | Déclaré ; accès utilisateurs précédemment confirmés | ACL fournisseur et origines non autorisées non établies ici |
| Portainer / Kuma / Netdata | Déclarés ; interfaces précédemment accessibles | Révisions runtime ne sont pas retestées par cette doc |
| Discord Netdata | Tests warning/critical/clear montrés par opérateur | Tests ≠ validation des seuils |
| 17 règles ciblées + 2 natives | Déclarées dans applications ; bind corrigé 768f95f | Chargement et évaluation après déploiement |
| AppArmor | LSM activé | Aucun profil applicatif enforcing déclaré |
| GitOps | Deux dépôts ; polling documenté | État comptes/sondes/secrets non entièrement IaC |
| Sauvegardes | Différées au propriétaire | Aucun test de restauration attesté |
| HA / supervision externe | Non déployées | Machine unique, panne totale possiblement silencieuse |

## 2. Résultats sécurité à ne pas surinterpréter

La [revue agent](../security/reports/20260930T140410Z-agent-review.md) termine
sans vulnérabilité serveur confirmée **dans sa couverture**.

- F-001 confirmé : défaut de couverture du workflow, pas vulnérabilité serveur.
  La découverte locale n'atteste pas l'exposition externe Windows ; retest prévu.
- F-002 candidate : vulnix termine code 2 ; résultat non concluant.
- Routeur, IPv6, appareils tailnet, attaques d'authentification et exploitation
  sont exclus de cette revue. Pas de conclusion « tout est cyber-secure ».

Les autres rapports restent accessibles dans l'[index](../security/reports/README.md).

## 3. Registre des limites d'architecture

Ce registre décrit des contraintes/écarts, pas de nouveaux findings confirmés.
Propriétaire : sobek. « Documenté » ne signifie pas risque accepté sans décision.

| ID | Limite | Contrôle actuel | Critère de sortie / action future |
| --- | --- | --- | --- |
| L-01 | Portainer avec socket Docker | Accès privé, compte applicatif, pas groupe Docker | Maintenir privilège explicite, revue accès/mises à jour |
| L-02 | Netdata PID hôte + SYS_PTRACE + racine + D-Bus | Pas socket Docker, no-new-privileges | Réduire/tester les accès sans perdre les collecteurs |
| L-03 | Certificats backend non vérifiés | TLS façade valide, bridges privés | Confiance/pinning backend revus et testés |
| L-04 | 9443 direct toujours publié | Docker guard LAN | Retrait après validation bootstrap/relais ; pas fait ici |
| L-05 | AppArmor sans profils ciblés | LSM et sysctl | Profil compatible Nix/containers, complain puis enforce |
| L-06 | Bridge partagé, sorties non allowlistées | Pas port app direct ; Kuma sortie dédiée | Besoin de segmentation/sortie explicite avant extension |
| L-07 | Caddy dans stack Kuma | Portainer Tailscale indépendant | Séparer le cycle proxy si le nombre de services le justifie |
| L-08 | Sondes et collecteurs co-localisés | Vues complémentaires | Sonde indépendante et détection absence de collecte |
| L-09 | État non entièrement versionné | Inventaire volumes/secrets/identités | Provisionnement sûr des éléments encore manuels |
| L-10 | Sauvegardes/RPO/RTO non attestés | Chantier propriétaire différé | Test de récupération indépendant de cette revue |
| L-11 | Pas de budget CPU/RAM garanti | Métriques, rétention bornée | Mesurer et fixer limites adaptées |
| L-12 | Vhost caddy de sondes sans ACL propre | Ports LAN restreints globalement | Vérifier/restrict origin si utilisé comme contrôle d'accès |

## 4. Comment mettre à jour cet état

Une attestation mentionne date, origine, commit, génération ou image, méthode,
résultat et limites. Ne pas recopier les secrets/preuves brutes.
Un commit correctif remplace « déclaré » ; seul un retest documenté remplace
« à attester ». Ne pas retoucher rétroactivement un rapport initial figé.
# Extension Homepage — 2026-10-01

Préparée, non déployée : image épinglée et YAML inline dans le dépôt apps,
réutilisation Caddy, listener dédié 8445 et relais Tailscale déclarés. La
validation Compose est statique ; aucun succès runtime ni accès client n'est
revendiqué. Les branches nécessitent revue et approbation d'activation avant
fusion dans main, qui peut déclencher le polling Portainer. Voir [HOMEPAGE.md](HOMEPAGE.md).
