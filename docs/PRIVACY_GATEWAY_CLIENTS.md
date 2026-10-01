# Clients de la passerelle privée

État : 2026-10-01. Windows testé ; Android et Android TV à configurer et
valider par leur propriétaire. Les libellés peuvent varier avec la version.

## Résultat attendu

| Réglage | Internet | DNS système |
| --- | --- | --- |
| Tailscale connecté, privacy-gateway sélectionnée | Mullvad via VM | DNS de l'exit node, AdGuard puis Mullvad |
| Tailscale connecté, pas d'exit node | Connexion habituelle | Dépend des préférences DNS Tailscale existantes |
| Tailscale déconnecté volontairement | Connexion habituelle | Réglages habituels de l'appareil |
| Exit node sélectionné, Mullvad indisponible | Blocage attendu, pas de fallback voulu | Résolution amont bloquée |

Un appareil connecté au tailnet n'utilise pas nécessairement l'exit node.
Sélection conservée et sélection obligatoire sont deux choses différentes.
Cette livraison ne verrouille aucun client et ne configure pas de DNS global
AdGuard pour les appareils sans exit node. Pas de politique auto:any, qui
pourrait sélectionner une autre sortie.

## Windows (MSI déjà dans le bon tailnet)

1. Icône Tailscale dans la zone de notification : Connected.
2. Exit node / nœud de sortie : sélectionner **privacy-gateway**.
3. Conserver l'utilisation des réglages DNS Tailscale.
4. Vérifier am.i.mullvad.net : sortie Mullvad puis test de fuites.
5. Déconnecter volontairement Tailscale pour revenir au réseau habituel.

Alternative PowerShell, chemin installé sur ce PC :

```powershell
& 'C:\Program Files\Tailscale\tailscale.exe' set --exit-node=100.116.220.6 --accept-dns=true
& 'C:\Program Files\Tailscale\tailscale.exe' status
```

Désélection sans déconnexion :

```powershell
& 'C:\Program Files\Tailscale\tailscale.exe' set --exit-node=
```

Allow LAN access est optionnel : l'activer seulement pour joindre les
imprimantes/autres équipements du réseau où se trouve le PC. Il introduit
une exception locale, pas une exception Internet. Les appareils du tailnet
restent administrables sans cette option. Ne pas désactiver la vérification TLS.
Tester après fermeture/réouverture de l'app et reboot ; pas de promesse de
sélection obligatoire sans politique Windows séparée.

## Android (Redmi déjà dans le bon tailnet)

1. Ouvrir Tailscale et connecter le VPN, accepter la demande Android.
2. Exit node / Use exit node : sélectionner **privacy-gateway**, pas
   Run as exit node qui transformerait le téléphone en passerelle.
3. Vérifier Mullvad dans le navigateur, puis l'application IPTV.

Ne pas exclure les applications concernées dans App split tunneling.
Pour utiliser AdGuard, éviter un fournisseur personnalisé de DNS privé
Android et un résolveur DoH personnalisé du navigateur. Régler DNS privé sur
désactivé pour la recette ; vérifier le comportement voulu hors Tailscale.
Ce choix client n'est pas automatisé par le serveur et peut nécessiter un
ajustement lors du retour au réseau habituel.

Android n'exécute normalement qu'un VPN applicatif à la fois : ne pas lancer
l'application Mullvad simultanément. C'est la VM qui porte Mullvad.
Autoriser Tailscale à fonctionner en arrière-plan si les économies d'énergie
interrompent le tunnel. Tester reconnexion, changement Wi-Fi/4G et reboot.

Ne pas activer aveuglément « bloquer les connexions sans VPN » : ce réglage
pourrait empêcher le retour normal à Internet lorsque Tailscale est volontairement
déconnecté, contrairement à l'objectif de ce projet.

## Android TV (encore dans l'ancien tailnet)

1. Sur la TV, ouvrir Tailscale et se déconnecter de l'ancien compte/tailnet.
2. Se reconnecter avec **le même compte GitHub que MSI et Redmi** ; terminer
   l'authentification à l'aide du lien/code proposé par l'app.
3. Dans la console Machines, vérifier la TV dans le même tailnet que homelab
   et privacy-gateway. Aucun secret ni auth key à transmettre dans le chat.
4. Dans l'app TV, sélectionner **privacy-gateway** comme exit node.
5. Vérifier les applications non exclues, tester la lecture IPTV puis un reboot.

Ne supprimer l'entrée de l'ancien tailnet qu'après validation du nouveau,
et seulement si cet ancien réseau doit être abandonné. Si le choix exit node
est absent, relever version Tailscale et modèle TV, mettre l'app à jour ;
ne pas compenser par l'annonce de routes ou une ouverture de ports.
La recette Windows ne prouve pas le comportement de la TV.

## Vérifications et diagnostic

- Mullvad indique sa sortie et ne détecte pas de fuite lors du test navigateur.
  L'adresse DNS Mullvad affichée est normale : AdGuard transmet à ce résolveur.
- Comparer le débit sur le même service et des tests répétés. Mesures Windows
  datées : ~10,8–13,6 Mbit/s après correction ; pas de capacité garantie.
- Une page de test réussie ne garantit pas toutes les applications. DoH peut
  éviter AdGuard même si sa connexion reste transportée dans Mullvad.
- Réseau local inaccessible : vérifier le besoin d'Allow LAN access, sans
  ouvrir le pare-feu de la passerelle ni annoncer le LAN du homelab.
- Internet coupé : vérifier exit node, état VM/Mullvad et DNS. En situation
  de récupération, désélectionner consciemment l'exit node rétablit la sortie
  habituelle, mais retire la protection Mullvad ; aucun fallback automatique.
- Les tests de panne actifs restent réservés à une fenêtre autorisée. Le
  script de kill switch s'exécute uniquement dans la VM, jamais sur l'hôte.

## Limites assumées

Pas d'HA, de MDM ou de garantie d'anonymat, de débit constant ou de contournement
de tout filtrage FAI/IPTV. Configuration des comptes clients, approbation
Tailscale et secrets demeurent de l'état externe à Git. Sauvegardes différées.

Sources officielles consultées le 2026-10-01 :
[exit nodes et DNS](https://tailscale.com/docs/features/exit-nodes),
[changement de compte](https://tailscale.com/docs/features/client/fast-user-switching).
Preuves et décisions du projet : [recette](PRIVACY_GATEWAY_VALIDATION.md),
[architecture](PRIVACY_GATEWAY.md), [décisions](../DECISIONS.md).
