# Migration IPTV : Dispatcharr + Jellyfin

Statut au 2026-10-02 : **préparée, non activée, lecture non validée**.
NetV reste intact. La génération active précédente reste la référence jusqu'à
validation. Ce document n'atteste ni le contournement d'un blocage fournisseur,
ni une garantie contre les mesures de censure ou la détection d'un VPN.

## Architecture et flux

```text
Windows / Android / Android TV (LAN ou Tailscale)
    | HTTPS privé :8447                 | HTTPS privé :8448 (administration)
    v                                  v
Tailscale Serve -> Caddy sur le LAN (pas de Funnel / redirection routeur)
    |                                  |
    v                                  v
Jellyfin ---- M3U + XMLTV internes ---> Dispatcharr ---- PostgreSQL + Redis
  .240.12                               .240.11          réseau media-data
                                            ^           interne uniquement
                                            |
                                       worker .240.13

Tout accès Internet de Jellyfin / Dispatcharr / worker :
  netv-egress -> VM apps0 .240.2 -> wg-mullvad -> fournisseur / métadonnées
  DNS -> AdGuard .240.2 -> DNS Mullvad via WireGuard
  VPN indisponible -> blocage ; jamais de reprise directe par le FAI

NetV .240.10 reste présent pendant la migration.
```

Les clients n'ont pas besoin de sélectionner l'exit node pour lire un flux
**relayé** par cette stack : la sortie fournisseur est imposée côté serveur.
Les autres applications du client ne passent par Mullvad que si l'exit node est
sélectionné. Ne pas choisir un profil Dispatcharr qui redirige le client vers
l'URL fournisseur : il contournerait le relais et cette propriété de sécurité.

## Contrat réseau

| Composant | Adresse / réseau | Accès autorisé |
| --- | --- | --- |
| NetV existant | 172.30.240.10 | Contrat précédent, conservé |
| Dispatcharr web / proxy | 172.30.240.11 | Internet via VM seulement ; ingress + data internes |
| Jellyfin | 172.30.240.12 | Internet via VM seulement ; ingress interne |
| Worker | 172.30.240.13 | Internet via VM seulement ; data interne, sans ingress |
| media-ingress | 172.30.243.0/28 | Caddy, Jellyfin et Dispatcharr uniquement |
| media-data | 172.30.244.0/28 | Web, worker, PostgreSQL et Redis uniquement |

Les deux nouveaux sous-réseaux ne chevauchent pas les routes observées sur
homelab avant préparation. Ils sont réservés à ce changement, pas à un scan de
cibles supplémentaires. Aucun port de base, cache ou application n'est publié
directement. Caddy lie 8447/8448 exclusivement à 192.168.1.69 ; le pare-feu Docker
existant limite les arrivées externes au LAN. Serve publie sur le tailnet.

Les règles source 4900..4903 utilisent la table 203. L'hôte et la VM utilisent
une liste de **quatre adresses**, pas une autorisation de tout le sous-réseau.
NAT et MSS 1380 restent limités à WireGuard ; IPv6 applicatif reste désactivé.
L'egress commun permet des communications L2 entre les quatre applications :
ce n'est pas une microsegmentation hostile entre workloads. Il ne contient ni
les services administratifs ni la base/cache. Ne pas y raccorder d'autre stack.

## Déploiement réversible

1. Relire les diffs infra et apps. Autoriser explicitement l'activation réseau,
   les redémarrages liés et le déploiement Docker. Ne pas pousser ces changements
   sur `main` avec un polling GitOps actif avant cette autorisation.
2. Depuis le checkout infra propre de staging, l'opérateur exécute :

   ```bash
   sudo bash scripts/media-deploy-test.sh
   ```

   Cela redémarre la VM (interruption temporaire de l'exit node / NetV), étend les
   allowlists et crée media-ingress. Le script restaure l'ancienne génération en
   cas d'échec de ses contrôles. Il ne change pas la génération de démarrage.
3. Publier la révision apps approuvée. Dans Portainer, créer `media-gitops` :
   dépôt homelab-apps, référence de migration approuvée, chemin
   `apps/media/compose.yaml`. Puis mettre à jour le stack Caddy/Kuma vers la même
   révision. Ne pas importer les changements Netdata encore préparés sur une
   autre branche par accident.
4. Créer les comptes via les interfaces privées, saisir la source chez
   Dispatcharr **manuellement**, puis effectuer les tests détaillés dans le
   README média du dépôt apps. Ne jamais copier les identifiants dans une issue,
   dans Git, une capture ou une sortie de diagnostic.
5. Après preuve de lecture et de fail-closed : fusionner les révisions revues,
   synchroniser `/etc/nixos`, puis l'opérateur effectue un `nixos-rebuild switch`.
   Valider ensuite la persistance au prochain redémarrage autorisé.
6. Retirer NetV uniquement après accord séparé. Ses volumes ne sont jamais
   supprimés par cette migration.

Rollback : arrêter uniquement le nouveau stack média, revenir à l'ancienne
révision Caddy, puis activer en `test` l'ancienne génération affichée par le
script. Ne pas utiliser `docker compose down -v` : les volumes contiennent
comptes, base et enregistrements. Vérifier de nouveau gateway, Serve et NetV.

## Durcissement et limites

- Versions et manifestes immuables vérifiés auprès de GHCR / Docker Hub.
- Secrets PostgreSQL et Redis générés au premier démarrage, volume root 0700,
  fichiers 0600, lecture runtime seulement. Aucune valeur dans Git ou les
  paramètres Portainer. Les rotations ultérieures exigent une migration DB,
  pas la suppression du volume de secrets.
- Jellyfin UID 10002, image read-only, aucune capability ; volumes dédiés 0700.
- Dispatcharr garde le démarrage root et les droits standard nécessaires à ses
  scripts upstream, sans NET_RAW, privilège global, montage hôte ou socket
  Docker. Le worker upstream reste root : risque résiduel déclaré, pas une
  prétention à un fonctionnement rootless. Les processus web sont abaissés par
  l'entrypoint upstream vers PUID 10003. Ne pas durcir à l'aveugle au prix d'un
  démarrage cassé.
- Pas de GPU exposé initialement, pas de transcodage systématique. Valider
  d'abord passthrough/remux et les codecs clients. Si nécessaire, ajouter le
  seul renderD128 à Jellyfin, avec groupe dédié vérifié et test QSV/VAAPI ; pas
  tout `/dev/dri`, pas de chmod du périphérique hôte.
- Limites mémoire cumulées des services permanents : 3840 MiB, hors NetV et
  services actuels. Ces plafonds ne sont pas une réservation. Ajuster après
  mesure de pression mémoire ; imports massifs EPG/VOD peuvent dépasser 768 MiB
  du worker. Mémoire disponible observée avant préparation : environ 5263 MiB.
- Pas de journal Docker persistant pour web/worker/Jellyfin, car les URLs de
  flux peuvent contenir des credentials. Logs Dispatcharr en tmpfs borné ;
  logs applicatifs Jellyfin dans son volume privé. Ne jamais récupérer un log
  brut sans revue/redaction. Cela limite la forensic ; mettre en place une
  collecte réellement expurgée avant d'élargir l'observabilité.
- M3U/XMLTV et enregistrements peuvent contenir des tokens ou des données
  sensibles : comptes séparés, mots de passe uniques, accès restreint, quotas
  et rétention des enregistrements avant usage DVR prolongé.
- Les sauvegardes sont différées à la demande du propriétaire. Une image
  reproductible ne remplace pas la sauvegarde des données et des secrets.

Serve partage désormais un verrou pour tous ses writers et attend l'état
Running, avec délais bornés. Sa configuration effective et les ACL du tailnet
doivent encore être vérifiées après activation : une règle de pare-feu sur
tailscale0 n'est pas une autorisation nominative de tous les membres du tailnet.

## Critères de recette

- Santé VM, DB, Redis, web, Jellyfin ; worker : tâche d'import effectivement
  traitée, pas seulement processus présent.
- Les trois services sortants montrent une sortie Mullvad ; aucune route
  alternative WAN/DNS/IPv6. Santé UI seule insuffisante.
- Test contrôlé de coupure VPN **autorisé séparément** : aucune sortie hors
  Mullvad, notification indépendante puis reprise et notification recovery.
- Une chaîne live autorisée pendant 10 minutes sous Windows puis Android TV :
  son/image stables, pas de boucle de redirection, pas de transcodage inutile.
- M3U consommé par Jellyfin contient des URLs Dispatcharr internes, pas les
  URLs fournisseur. Respecter le nombre de connexions de l'abonnement.
- Accès Jellyfin/Dispatcharr LAN + Tailscale ; pas d'ouverture Internet ;
  authentification obligatoire, compte lecture distinct de l'administration.
- Débit/CPU/RAM et logs sensibles revus. VOD/replay et DVR ont des tests séparés.

Références : [Dispatcharr installation](https://dispatcharr.github.io/Dispatcharr-Docs/installation/),
[Jellyfin conteneurs](https://jellyfin.org/docs/general/installation/container/),
[Jellyfin Live TV](https://jellyfin.org/docs/general/server/live-tv/).
