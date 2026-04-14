# WAN VACE — Prévisualisation frames au clic

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ouvrir le popup plein écran au clic sur une miniature de la grille de résultats WAN VACE.

**Architecture:** Ajout d'un appel à `_show_preview_fn` dans le handler `gui_input` existant de `_add_result_cell`. Aucun nouveau composant. La sélection + sauvegarde restent inchangées.

**Tech Stack:** GDScript 4, GUT (tests headless), Godot 4.6.1.

---

### Task 1 : Ouvrir le popup au clic sur la miniature

**Files:**
- Modify: `plugins/ai_studio/ai_studio_wan_vace_tab.gd:619-628`

#### Contexte

`_add_result_cell` (ligne 614) crée une cellule par frame générée. Son `TextureRect` a déjà un handler `gui_input` qui appelle `_select_frame(image, index)` au clic gauche. Il suffit d'y ajouter l'appel à `_show_preview_fn`.

`_show_preview_fn` est un `Callable` injecté via `initialize()` qui prend `(texture: Texture2D, filename: String)` et ouvre le popup plein écran `ImagePreviewPopup`.

#### Code actuel (lignes 625-628)

```gdscript
tex_rect.gui_input.connect(func(event: InputEvent):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _select_frame(image, index)
)
```

- [ ] **Step 1 : Appliquer la modification**

Remplacer le handler ci-dessus par :

```gdscript
tex_rect.gui_input.connect(func(event: InputEvent):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _select_frame(image, index)
        _show_preview_fn.call(tex_rect.texture, "Frame %d" % (index + 1))
)
```

- [ ] **Step 2 : Vérifier qu'il n'y a pas d'erreur de compilation**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . --check-only 2>&1 | grep -E "ERROR|Parse Error"
```

Expected: aucune sortie (0 erreurs).

- [ ] **Step 3 : Lancer le fichier de test le plus proche**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://specs/services/test_comfyui_client_wan_vace.gd 2>&1 | tail -20
```

Expected: tous les tests passent (42 tests, 0 failures).

- [ ] **Step 4 : Commit**

```bash
git add plugins/ai_studio/ai_studio_wan_vace_tab.gd
git commit -m "feat: ouvrir popup plein écran au clic sur miniature WAN VACE"
```

Puis mettre à jour le pointeur submodule dans le dépôt parent :

```bash
cd /chemin/vers/visual-builder
git add plugins/ai_studio
git commit -m "chore: update ai_studio submodule (frame preview on click)"
git push
```
