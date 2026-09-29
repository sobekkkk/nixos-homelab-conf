# Rapport consolidé des constats de sécurité — homelab

## Synthèse

La revue n'a confirmé aucune exposition réseau non documentée dans l'état
capturé. Les contrôles réseau, SSH, LUKS2, Secure Boot, auditd et la garde
Docker sont présents dans le snapshot. Ce document réunit les huit constats
des revues white-box et du scan Codex Security. F-08 ajoute un risque de
premier démarrage de Portainer ; l'état du volume actuel ne permet pas de
déterminer si cette fenêtre d'initialisation existe encore.

Cette évaluation est une photographie : elle ne prouve ni la topologie du LAN,
ni le routeur, ni l'accessibilité depuis Internet.

## Cadre de l'évaluation

| Élément | Valeur |
| --- | --- |
| Date de l'audit | 2026-09-29 |
| Actif autorisé | `homelab` (`192.168.1.69`) |
| Mode | Revue white-box initiale en lecture seule par `sobek`, puis consolidation statique par Codex |
| Révision revue | `8bb42ace1f1a6c1b58aa73e3b6bd84dcad59f6f7` |
| État Git lors de la revue initiale | propre ; `git fsck` sans erreur d'intégrité |
| Snapshot de la revue initiale | `20260929T172948Z`, généré le `2026-09-29T17:29:48+00:00` |

L'autorisation, le périmètre et les interdictions proviennent de `AGENTS.md`,
`security/ROE.md` et `security/scope.yml`. La revue initiale a consulté
`/etc/nixos` et `/var/lib/homelab-security-snapshot/latest`. F-08 provient
d'une revue statique de la même révision du dépôt, rapprochée de la
documentation officielle de Portainer. Aucun état supplémentaire du serveur
n'a été consulté pour ce constat.

Les opérations suivantes n'ont pas été réalisées : `sudo`, accès au socket
Docker, écriture sur l'hôte, redémarrage, activation NixOS, scan réseau,
authentification répétée, scan web ou test d'exploitation.

## Méthode et éléments de preuve

La configuration déclarée a été corrélée avec les fichiers curatés du
snapshot : `sockets.txt`, `nftables.txt`, `docker-user-ipv4.txt`,
`docker-user-ipv6.txt`, `ssh-effective.txt`, `services.txt`,
`audit-rules.txt`, `apparmor.txt`, `secure-boot.txt`, `boot.txt`, `luks.txt`,
`docker-version.txt`, `docker-info.txt`, `docker-containers.txt` et
`docker-runtime.txt`.

Les sources de configuration principales sont `modules/firewall.nix`,
`modules/ssh.nix`, `modules/containers.nix`, `modules/auditing.nix`,
`modules/boot.nix`, `modules/hardening.nix` et
`stacks/uptime-kuma/compose.yaml`. Les preuves brutes ne sont pas ajoutées à ce
dépôt.

| Constats | Origine | Nature de la preuve |
| --- | --- | --- |
| F-01 à F-04 | Revue white-box initiale | Configuration et snapshot en lecture seule |
| F-05 à F-07 | Revue statique complémentaire | Configuration, documentation et snapshot existant |
| F-08 | Scan Codex Security `357707ba-e6c2-461c-81a7-7f0b5723f1e9`, rapproché de la documentation Portainer | Configuration et scénario de premier démarrage ; aucun test du service |

## Surface d'attaque : déclaré et observé

| Domaine | Déclaré | Observé dans le snapshot | Évaluation |
| --- | --- | --- | --- |
| SSH | TCP/22, source IPv4 `192.168.1.0/24` | écoute `0.0.0.0:22` et `[::]:22`; nftables n'accepte TCP/22 que depuis le LAN IPv4 | Conforme ; l'écoute IPv6 ne constitue pas à elle seule une autorisation IPv6. |
| Portainer | TCP/9443, temporairement maintenu durant la migration | Portainer CE 2.39.0 actif, publication `0.0.0.0:9443->9443/tcp` | Conforme à l'exception de migration ; accès direct encore présent. |
| Proxy / supervision | Caddy doit publier TCP/443 ; Kuma ne doit pas publier de port hôte | aucun écouteur TCP/443, Caddy et Kuma absents ; seul Portainer est présent | Déploiement de supervision non observé. |
| Ports interdits | pas de 80, 8000, 9000, 3001 ni API Docker TCP | aucun de ces ports n'est en écoute hôte | Conforme dans le snapshot. |
| Docker | aucune API TCP ; garde `DOCKER-USER` IPv4/IPv6 | chaîne `HOMELAB-DOCKER-GUARD` référencée par les deux chaînes `DOCKER-USER` | Conforme, sous la réserve d'interface décrite ci-dessous. |

## Contrôles positifs vérifiés

- Le pare-feu nftables a une politique `input drop`; la seule règle TCP entrante
  déclarée est SSH depuis le LAN IPv4.
- SSH applique `PermitRootLogin no`, `PasswordAuthentication no`,
  `KbdInteractiveAuthentication no`, `AllowUsers sobek`, `MaxAuthTries 3` et
  désactive les transferts agent, TCP, X11, socket Unix et tunnels.
- `auditd`, `systemd-journald`, `docker`, `docker-portainer` et `sshd` sont
  actifs dans la capture. Les règles d'audit sur NixOS, SSH et les clés Secure
  Boot sont chargées.
- Secure Boot est activé, un UKI mesuré est signalé, le support TPM2 est
  présent, et `cryptroot` est actif en LUKS2 AES-XTS 512 bits.
- Portainer n'est pas privilégié au sens Docker (`privileged=false`) ; il
  conserve toutefois, par conception, un montage RW du socket Docker.

## Findings et écarts

### F-01 — Garde Docker liée à une interface nommée

| Champ | Valeur |
| --- | --- |
| Statut | candidate |
| Sévérité potentielle | Haute |
| Confiance | Moyenne |
| Actif concerné | Publications Docker, notamment Portainer TCP/9443 |

`modules/containers.nix` et `nftables.txt` montrent que le rejet IPv4 des
sources hors LAN et le rejet IPv6 des ports Docker sont conditionnés à
`-i wlp0s20f3`. Une interface supplémentaire ou renommée offrant une entrée
vers l'hôte pourrait ne pas satisfaire cette condition. Le snapshot ne contient
pas l'inventaire des interfaces ni la topologie de routage : aucune exposition
hors LAN n'est donc prouvée.

Impact conditionnel : si un chemin non-LAN arrivait par une autre interface,
Portainer pourrait être atteignable ; son socket Docker lui donne une capacité
d'administration de l'hôte proche de root.

Retest proposé, après autorisation : confirmer l'interface d'entrée et les
règles de filtrage pour chaque interface active, puis vérifier que la chaîne
Docker refuse les sources non-LAN dans chaque cas.

### F-02 — État d'enforcement AppArmor non établi

| Champ | Valeur |
| --- | --- |
| Statut | candidate |
| Sévérité potentielle | Moyenne |
| Confiance | Moyenne |
| Actif concerné | Durcissement des processus locaux et conteneurs |

`modules/hardening.nix` active AppArmor, et la ligne de démarrage capturée
inclut `apparmor=1`. Toutefois, `apparmor.txt` indique que le module est chargé
mais que `aa-status` n'a pas pu obtenir la liste des profils. Le snapshot ne
permet donc pas de démontrer que des profils sont chargés et appliqués. Cela ne
prouve pas qu'AppArmor soit désactivé.

Retest proposé, après autorisation : identifier la cause de l'échec de
`aa-status`, puis vérifier les profils en enforce et leur couverture des
services concernés.

### F-03 — Entrée de démarrage courante différente de l'entrée par défaut

| Champ | Valeur |
| --- | --- |
| Statut | candidate |
| Sévérité potentielle | Basse |
| Confiance | Haute |
| Actif concerné | Prévisibilité du prochain démarrage |

`boot.txt` rapporte une entrée courante en génération 21, tandis que l'entrée
par défaut est la génération 27 datée du 29 septembre. Ce décalage est
compatible avec un `nixos-rebuild switch` sans redémarrage et ne prouve pas une
erreur. Le snapshot ne contient pas l'information suffisante pour relier la
génération des services actifs à la révision Git évaluée.

Retest proposé : avant le prochain redémarrage planifié, comparer la génération
active, l'entrée par défaut et le diff de configuration prévu; valider le
démarrage de la génération 27 avec un accès console de récupération disponible.

### F-04 — Proxy Caddy et supervision non déployés dans l'état observé

| Champ | Valeur |
| --- | --- |
| Statut | accepted-risk / écart de déploiement |
| Sévérité potentielle | Basse |
| Confiance | Haute |
| Actif concerné | Interface web locale et supervision |

Le compose déclare Caddy sur TCP/443 et Uptime Kuma sans port hôte. Le snapshot
ne contient cependant qu'un conteneur Portainer et aucune écoute TCP/443. Le
port direct 9443 demeure la seule interface web. Cette situation est conforme à
l'exception de migration documentée, limitée au LAN par la garde Docker, mais
la réduction prévue de surface d'exposition n'est pas encore réalisée.

Retest proposé : après un déploiement approuvé, vérifier l'accès Caddy depuis
le LAN, l'absence de publication de Kuma et le retrait de TCP/9443 seulement
lorsque la migration est validée.

### F-05 — Amorçage TLS de Portainer sans identité serveur vérifiable

| Champ | Valeur |
| --- | --- |
| Statut | candidate |
| Sévérité potentielle | Haute |
| Confiance | Moyenne |
| Actif concerné | Portainer TCP/9443 et capacité d'administration Docker |

Le snapshot confirme que Portainer est encore publié en TCP/9443. Sa
configuration déclare une image Portainer reliée au socket Docker
(`modules/containers.nix:19-29`). La procédure d'amorçage documente un
certificat auto-signé et demande à l'opérateur d'accepter l'avertissement du
navigateur avant de créer le premier administrateur
(`docs/CONTAINERS.md:27-35`, `docs/OPERATIONS.md:120-123`). Cette séquence ne
fournit pas une identité serveur authentifiée par défaut.

Chemin d'attaque conditionnel : un appareil hostile déjà en position
d'interception sur le LAN présente un certificat différent ; si l'opérateur
accepte l'exception, il peut divulguer le mot de passe ou la session Portainer.
Le compte Portainer peut ensuite administrer Docker grâce au socket monté en
écriture, ce qui offre une capacité proche de root sur l'hôte. Cette attaque
nécessite l'interception du trafic et l'acceptation humaine d'une alerte TLS ;
elle n'est donc pas confirmée par le snapshot.

Retest proposé, sans modification : relever l'empreinte du certificat servi
par TCP/9443 depuis un poste de confiance et la comparer à une valeur obtenue
hors bande sur la console du serveur. Confirmer ensuite le retrait de 9443
lorsque l'autorité Caddy est installée et vérifiée sur les clients approuvés.

### F-06 — Images de conteneurs référencées par tag et non par digest

| Champ | Valeur |
| --- | --- |
| Statut | candidate |
| Sévérité potentielle | Haute |
| Confiance | Moyenne |
| Actif concerné | Chaîne d'approvisionnement Portainer, Caddy et Uptime Kuma |

Portainer est déclaré avec le tag `portainer/portainer-ce:2.39.0` et
`pull = "missing"` (`modules/containers.nix:18-29`). Caddy et Uptime Kuma sont
également déclarés par tag (`stacks/uptime-kuma/compose.yaml:2-30`) plutôt que
par digest immuable. Un tag versionné réduit le risque par rapport à `latest`,
mais ne lie pas cryptographiquement le déploiement à un manifeste d'image
précis.

Chemin d'attaque conditionnel : lors d'un premier pull ou d'un remplacement
d'image, une compromission du registre, du compte éditeur ou de la chaîne de
récupération peut fournir une image différente sous le même tag. Pour
Portainer, une telle image recevrait le socket Docker et pourrait prendre le
contrôle de l'hôte. Aucun compromis de registre, pull malveillant ou image
inattendue n'est démontré dans le snapshot.

Retest proposé, sans pull ni redéploiement : relever les `RepoDigests` des
images exécutées dans le snapshot ou par inspection Docker en lecture seule,
puis les comparer aux digests publiés par les éditeurs. Conserver la valeur
vérifiée dans la revue de changement avant une mise à jour.

### F-07 — Absence de cadence définie de mise à jour de sécurité

| Champ | Valeur |
| --- | --- |
| Statut | candidate |
| Sévérité potentielle | Moyenne |
| Confiance | Élevée |
| Actif concerné | NixOS, OpenSSH et images de services exposés au LAN |

Les mises à jour automatiques sont explicitement désactivées
(`modules/maintenance.nix:4-6`) et les mises à jour de `nixpkgs` restent
manuelles (`docs/OPERATIONS.md:84-105`). Le modèle de menaces identifie déjà
le délai d'application des correctifs comme un scénario à risque
(`docs/THREAT_MODEL.md:124`). Aucun CVE précis ni composant vulnérable actif
n'a été établi dans cette revue ; l'absence de cadence constitue donc un risque
opérationnel, non une vulnérabilité confirmée.

Chemin d'attaque conditionnel : après la publication d'un correctif pour un
service joignable depuis le LAN, une fenêtre de non-mise-à-jour peut permettre
l'exploitation de la version conservée. L'impact dépendra du composant affecté
et peut être élevé pour SSH ou Portainer.

Retest proposé, sans changement : relever les versions et digests réellement
exécutés, les comparer périodiquement aux avis NixOS et éditeurs, puis vérifier
qu'une cadence de revue, un propriétaire et un délai maximal de correction sont
documentés.

### F-08 — Prise possible du premier compte administrateur Portainer

| Champ | Valeur |
| --- | --- |
| Statut | candidate |
| Sévérité potentielle | Moyenne |
| Confiance | Moyenne |
| Actif concerné | Portainer TCP/9443, premier compte administrateur et socket Docker |

`modules/containers.nix:18-29` publie `9443:9443`, conserve l'état dans
`portainer_data` et monte le socket Docker en écriture. La garde de
`modules/containers.nix:55-73` autorise tout le LAN IPv4
`192.168.1.0/24`, sans restriction temporaire au poste de l'opérateur.
`docs/OPERATIONS.md:120-123` prévoit la création du premier compte après le
démarrage de Portainer.

La [documentation officielle de l'installation initiale de Portainer](https://docs.portainer.io/start/install-ce/server/setup)
indique que le premier utilisateur créé est administrateur. Sa
[FAQ sur le délai d'initialisation](https://docs.portainer.io/faqs/installing/your-portainer-instance-has-timed-out-for-security-purposes-error-fix)
décrit une fenêtre de cinq minutes destinée à empêcher qu'un tiers ne
configure une instance neuve avant son propriétaire. La
[documentation de l'API Portainer](https://docs.portainer.io/api/examples)
décrit également l'initialisation du compte avant l'authentification. Le
comportement exact de l'image épinglée `2.39.0` n'a pas été testé ici.

Chemin d'attaque conditionnel : avec un volume `portainer_data` vide ou
réinitialisé, un appareil hostile déjà présent sur le LAN atteint TCP/9443
pendant la fenêtre de premier démarrage et crée le compte avant l'opérateur.
Il obtient alors l'administration de Portainer, puis sa capacité Docker proche
de `root` grâce au socket monté. Le snapshot montre un Portainer actif et le
port 9443 publié, mais ne démontre **ni** un volume vide **ni** une prise de
compte réelle. Ce finding ne prouve pas une compromission actuelle.

Mesure proposée : pendant une installation neuve ou une restauration approuvée,
limiter temporairement TCP/9443 au seul poste d'administration explicitement
autorisé. Créer et vérifier le compte initial avant d'appliquer la politique
LAN prévue. Une préinitialisation par un mécanisme Portainer adapté peut aussi
être envisagée, avec le secret strictement hors Git, hors store Nix et hors
journaux.

Retest proposé, après autorisation de la maintenance : vérifier la règle
effective de premier démarrage et confirmer qu'une source LAN non autorisée ne
peut pas atteindre l'initialisation avant l'opérateur. Consigner l'heure, la
révision, la règle et le résultat expurgé ; ne pas créer de compte pendant
l'audit du serveur en service.

## Risques documentés et limites de preuve

- Les sauvegardes automatisées de Portainer, Caddy et Kuma ne sont pas encore
  définies. C'est un risque de disponibilité documenté, pas une vulnérabilité
  d'accès démontrée.
- La capture établit la présence de LUKS2, Secure Boot, UKI mesuré et TPM2,
  mais pas le contenu d'un token TPM2 ni l'exigence effective d'un PIN.
- Les services de journalisation et les règles d'audit sont établis, mais le
  snapshot ne contient ni événements de journal, ni preuve de rétention réelle,
  ni état des unités en échec.
- Les blobs Git orphelins signalés par `git fsck` ne sont pas référencés par
  `HEAD` et n'affectent pas la construction; leur contenu n'a pas été consulté
  afin d'éviter toute exposition potentielle de données historiques.

## Priorités

1. Restreindre l'accès au premier démarrage de Portainer au poste de
   l'opérateur, avant toute installation neuve ou restauration du volume.
2. Vérifier que la garde Docker couvre toute interface pouvant devenir une
   entrée réseau, avant d'ajouter un service ou une interface.
3. Ne plus accepter d'exception TLS pour l'administration : vérifier une
   identité de serveur hors bande durant l'amorçage et retirer TCP/9443 après
   la migration Caddy validée.
4. Épingler les images de production par digest vérifié, particulièrement celle
   de Portainer qui reçoit le socket Docker.
5. Définir une cadence de revue des avis de sécurité et un délai maximal de
   correction pour NixOS et les images exécutées.
6. Restaurer une preuve fiable des profils AppArmor effectivement appliqués.
7. Avant un redémarrage, confirmer la génération cible et conserver une voie de
   récupération.
8. Définir, tester et documenter les sauvegardes des volumes avant d'y stocker
   des données importantes.

## Conclusion

Les mécanismes centraux attendus sont observés dans la photographie disponible
et aucune exposition non documentée n'est confirmée. Les findings restent des
candidats ou des risques explicitement acceptés tant que les vérifications
proposées n'ont pas été autorisées et réalisées. F-08 concerne uniquement une
future installation ou restauration avec un volume Portainer non initialisé ;
le rapport ne démontre pas cette condition sur le serveur actuel.
