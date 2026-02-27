# 019 — TextureLoader

## Contexte

`sequence_visual_editor.gd` et `foreground_transition.gd` contenaient la même fonction `_load_texture()` de 14 lignes identiques.

## Solution

`TextureLoader` (RefCounted, fonction statique `load_texture()`) centralise le chargement de textures avec double mode (ressource Godot ou fichier externe).

## Fichier

`src/ui/texture_loader.gd`
