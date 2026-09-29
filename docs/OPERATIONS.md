# Exploitation quotidienne

## Vérifications rapides

```bash
sudo sbctl status
systemctl --failed
sudo cryptsetup status cryptroot
```

## Snapshot de sécurité pour l'audit

Après avoir construit et activé une version contenant
`modules/security-snapshot.nix`, déclencher un snapshot à la demande avec :

```bash
sudo systemctl start homelab-security-snapshot.service
ls -l /var/lib/homelab-security-snapshot/latest
```

Le groupe `homelab-audit` permet à `sobek` de lire uniquement ce snapshot
curaté. Il ne donne ni `sudo` ni accès au socket Docker. Les snapshots sont
root-owned, expirent après 14 jours et excluent volontairement les variables
d'environnement des conteneurs afin de ne pas exposer de secrets.

Pour consulter les journaux du démarrage courant :

```bash
sudo journalctl -b --no-pager
```

Pour filtrer l'audit des changements de configuration, après activation du
module d'audit :

```bash
sudo ausearch -k nixos-configuration -i
sudo ausearch -k ssh-configuration -i
sudo ausearch -k secure-boot-keys -i
```

## Mettre à jour la configuration

```bash
cd /etc/nixos
git status
git diff
sudo nixos-rebuild test --flake .#homelab
sudo nixos-rebuild switch --flake .#homelab
```

`test` active temporairement la génération et permet de vérifier un changement
avant de le rendre persistant au prochain démarrage avec `switch`.

## Retour arrière

Si une nouvelle génération pose problème :

1. démarrer sur une génération précédente depuis le menu de boot ;
2. ou lancer `sudo nixos-rebuild switch --rollback` depuis un système encore
   accessible ;
3. lire les journaux avant de modifier de nouveau la configuration.

## Sauvegarde LUKS

Une modification des slots LUKS (mot de passe, recovery key, TPM) mérite une
nouvelle sauvegarde du header. Elle doit être copiée hors du serveur et traitée
comme une information sensible. Ne jamais la committer.

Les sauvegardes automatisées du système et des futurs services feront l'objet
d'un document dédié dès que la destination sera choisie.

## Maintenance Nix

Le système effectue automatiquement deux opérations le dimanche :

- garbage collection à partir de 03:15, avec un délai aléatoire maximal de
  30 minutes ;
- optimisation du store à partir de 04:15, avec le même délai aléatoire.

Le garbage collector supprime les générations inutilisées âgées de plus de
30 jours. La génération active et les chemins encore référencés restent
protégés par les racines du store Nix.

Les mises à jour de nixpkgs restent manuelles. Pour mettre à jour uniquement
l'entrée `nixpkgs` du flake :

```bash
cd /etc/nixos
sudo nix flake update nixpkgs --flake /etc/nixos
git diff -- flake.lock
```

Vérifier et construire avant toute activation :

```bash
git diff --check
nix eval --raw .#nixosConfigurations.homelab.config.system.build.toplevel.drvPath
nix build .#nixosConfigurations.homelab.config.system.build.toplevel --no-link
sudo nixos-rebuild test --flake .#homelab
```

Après les contrôles fonctionnels, rendre la génération permanente :

```bash
sudo nixos-rebuild switch --flake .#homelab
```

Si le réseau ou SSH change, conserver la session en cours et tester une seconde
connexion avant le `switch`.

## Portainer et Docker

Portainer est volontairement le seul conteneur déclaré par NixOS. Après son
premier `switch`, ouvrir depuis un appareil du LAN :

```text
https://192.168.1.69:9443
```

Le certificat est auto-signé au premier démarrage : cette exception est limitée
à l'amorçage de Portainer avant le déploiement de Caddy. Depuis un poste de
confiance, vérifier l'adresse et l'empreinte hors bande avant toute exception,
puis créer sans attendre le premier compte administrateur (mot de passe unique
d'au moins 12 caractères). L'environnement Docker local doit être détecté
automatiquement. Lors d'une recréation du volume `portainer_data`, préparer une
fenêtre de maintenance et limiter temporairement 9443 au seul poste
d'administration avant de créer ce compte.

Vérifier la plateforme sans donner le socket Docker au compte `sobek` :

```bash
sudo systemctl status docker docker-lan-guard docker-portainer
sudo docker ps
sudo iptables -S DOCKER-USER
sudo ss -lntp | grep ':9443'
```

`docker-lan-guard` doit être actif avant `docker-portainer`. La règle
`HOMELAB-DOCKER-GUARD` limite les ports publiés au LAN quelle que soit
l'interface physique ; ne pas la retirer pour "faire marcher" un service. Les
seuls retours autorisés concernent la boucle locale et les bridges Docker, pour
préserver les flux internes.

Ne pas activer les ports 80, 443, 8000 ou 9000 par défaut. Un premier service
doit avoir un compose/stack versionné dans un dépôt privé, ses données et sa
sauvegarde documentées, puis être déployé depuis Portainer. La mise à jour de
Portainer consiste à modifier le tag **et le digest** d'image dans
`modules/containers.nix`, revoir le diff, reconstruire puis vérifier que le
volume `portainer_data` est toujours présent.

## Cadence de sécurité

Les mises à jour restent manuelles pour préserver une revue humaine de la
chaîne de démarrage et du réseau, mais elles suivent désormais une cadence
explicite :

- `sobek` consulte au moins toutes les deux semaines les avis NixOS et les
  versions publiées de Portainer, Caddy et Uptime Kuma ;
- un correctif de sécurité connu pour un service exposé au LAN est évalué sous
  sept jours ; les autres mises à jour sont regroupées dans la revue mensuelle ;
- chaque mise à jour d'image vérifie le nouveau digest publié par l'éditeur,
  puis suit `nixos-rebuild test` avant `switch` ;
- le résultat (mise à jour, report et raison) est noté dans le commit ou dans
  `DECISIONS.md`, sans y copier de secret.

Les digests actuels ont été vérifiés le 29 septembre 2026 auprès de Docker Hub :

| Service | Référence revue |
| --- | --- |
| Portainer CE | `2.39.0@sha256:3267f1869e0fa87b843c55f7fd848f9e3001367d053505f4cb8c664e4a997996` |
| Caddy | `2.11.4-alpine@sha256:6aeddd44c3078b0f9a35206472a11420648a79c184603ef95957d0a20044cb2b` |
| Uptime Kuma | `2.5.5@sha256:c74379ac4509ce2d2c2633f509e67003ee2e45b6e995c5e43fc101f45a0e1fbe` |
