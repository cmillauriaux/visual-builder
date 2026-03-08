# 064 — Popup d'installation PWA (iOS / Android)

## Contexte

Sur le web, les utilisateurs mobiles (iOS et Android) bénéficient d'une meilleure expérience en installant l'application comme PWA : plein écran, icône sur l'écran d'accueil, mode hors ligne. Une popup explicative doit les guider selon leur plateforme.

## Exigences

### Détection de plateforme

1. Sur le web uniquement (`OS.get_name() == "Web"`), détecter la plateforme mobile via `navigator.userAgent` (JavaScriptBridge).
2. Détecter iOS : user-agent contient "iphone" ou "ipad".
3. Détecter Android : user-agent contient "android".
4. Ne rien afficher sur desktop ou si la plateforme n'est ni iOS ni Android.
5. Ne rien afficher si l'app tourne déjà en mode standalone/PWA (vérifier `window.matchMedia('(display-mode: standalone)').matches` ou `window.navigator.standalone`).

### Popup d'installation

6. Afficher une popup modale au-dessus du menu principal, après le chargement de la story.
7. La popup utilise le thème Kenney (PanelContainer avec GameTheme).
8. Contenu pour **iOS** :
   - Titre : "Installer l'application"
   - Message : "Pour une meilleure expérience (plein écran, mode hors ligne), installez l'application :\n\n1. Appuyez sur le bouton de partage (⎙)\n2. Sélectionnez « Sur l'écran d'accueil »"
9. Contenu pour **Android** :
   - Titre : "Installer l'application"
   - Message : "Pour une meilleure expérience (plein écran, mode hors ligne), installez l'application :\n\n1. Ouvrez le menu (⋮) de votre navigateur\n2. Sélectionnez « Installer l'application » ou « Ajouter à l'écran d'accueil »"
10. Un bouton "Compris" pour fermer la popup.
11. Une case à cocher "Ne plus afficher ce message" en bas de la popup.

### Persistance

12. Ajouter un paramètre `pwa_prompt_dismissed` (bool, défaut `false`) dans `GameSettings`.
13. Sauvegarder et charger ce paramètre dans `settings.cfg` sous `[display] pwa_prompt_dismissed`.
14. Si `pwa_prompt_dismissed` est `true`, ne pas afficher la popup.

### Intégration

15. La popup est affichée dans `game.gd` après `_show_main_menu()`, uniquement si les conditions sont remplies (web + mobile + pas dismissed + pas standalone).
16. Quand l'utilisateur ferme la popup avec la case cochée, sauvegarder `pwa_prompt_dismissed = true`.

## Critères d'acceptation

- [ ] `PwaInstallPrompt` détecte correctement iOS via user-agent.
- [ ] `PwaInstallPrompt` détecte correctement Android via user-agent.
- [ ] `PwaInstallPrompt` ne s'affiche pas sur desktop web.
- [ ] `PwaInstallPrompt` ne s'affiche pas si déjà en mode standalone.
- [ ] Le message affiché est spécifique à la plateforme détectée (iOS vs Android).
- [ ] La case "Ne plus afficher" persiste le choix via `GameSettings`.
- [ ] `GameSettings` a la propriété `pwa_prompt_dismissed` (défaut false).
- [ ] `GameSettings` sauvegarde et charge `pwa_prompt_dismissed` dans `settings.cfg`.
- [ ] La popup se ferme avec le bouton "Compris".
- [ ] La popup n'apparaît pas si `pwa_prompt_dismissed` est true.
- [ ] La popup s'affiche au-dessus du menu principal avec le thème Kenney.
