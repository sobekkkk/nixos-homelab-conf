# Contribuer sans se prendre la tête

Ce homelab sert d'abord à apprendre. Une bonne contribution est donc une
contribution qui rend le système plus clair, plus sûr ou plus facile à réparer.

## Avant un commit

1. Relire le diff et vérifier qu'il ne contient aucun secret.
2. Mettre à jour le README ou un fichier dans `docs/` si le comportement,
   l'architecture ou une commande change.
3. Vérifier la configuration :

   ```bash
   cd /etc/nixos
   git diff --check
   nix eval --raw .#nixosConfigurations.homelab.config.system.build.toplevel.drvPath
   ```

4. Utiliser un message de commit court qui explique l'intention, par exemple
   `Enable persistent audit logging`.

## Quelques habitudes utiles

- Préférer les petits changements indépendants aux gros changements difficiles à
  diagnostiquer.
- Tester avec `nixos-rebuild test` avant `switch` lorsqu'un service ou le réseau
  est concerné.
- Ne pas ouvrir de port ou ajouter de service public sans l'avoir documenté.
- Garder les détails personnels et les secrets hors de Git.
- Pour un stack conteneur, documenter ses ports, ses volumes, ses mises à jour
  et sa sauvegarde avant son premier déploiement dans Portainer.

Le projet peut évoluer tranquillement : documenter ce qui a été appris compte
autant que faire fonctionner la machine.
