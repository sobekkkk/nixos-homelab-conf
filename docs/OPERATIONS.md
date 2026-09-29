# Exploitation quotidienne

## Vérifications rapides

```bash
sudo sbctl status
systemctl --failed
sudo cryptsetup status cryptroot
```

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
