# Agent Codex

Codex CLI est installé par NixOS avec le paquet `codex` déclaré dans
`modules/packages.nix`. Il est utilisé comme assistant interactif depuis une
session SSH, pas comme un service permanent.

## Première connexion

Le serveur n'ayant pas de navigateur graphique, utiliser la connexion par code
d'appareil :

```bash
codex login --device-auth
```

Ouvrir l'adresse affichée depuis un navigateur de confiance, saisir le code à
usage unique, puis vérifier la session :

```bash
codex login status
```

Il est également possible d'utiliser une clé API pour une future automatisation,
mais elle implique une facturation API distincte. Aucun token ou clé ne doit être
ajouté à la configuration NixOS, au dépôt Git ou à l'historique du shell.

## Règles d'utilisation dans le lab

- lancer `codex` avec le compte `sobek`, jamais avec `sudo` ;
- commencer dans le dépôt ou le dossier réellement concerné ;
- vérifier les permissions actives avec `/permissions` ;
- relire les commandes, les diffs et les fichiers générés avant application ;
- garder les opérations privilégiées, le rebuild et le reboot sous contrôle
  humain explicite.

Le dépôt `/etc/nixos` appartient à `sobek` afin que Git puisse mettre à jour la
configuration sans mélange de permissions. Cela ne donne pas le droit d'activer
un changement : `nixos-rebuild` reste une opération `sudo`, avec revue du diff
et mot de passe. Pour les changements importants, l'agent peut aussi travailler
dans un clone appartenant à `sobek`, puis le diff est relu avant activation.

## Identifiants

Sur une machine sans trousseau de clés, Codex peut conserver sa session dans
`~/.codex/auth.json`. Ce fichier contient des jetons d'accès et doit être traité
comme un mot de passe : permissions restrictives, aucune copie dans Git, dans
les logs ou dans une conversation.

Pour fermer la session et retirer les identifiants enregistrés :

```bash
codex logout
```

## Démarrer

```bash
cd ~/src/un-projet
codex
```

La commande `/init` peut ensuite créer un fichier `AGENTS.md` propre au projet.
