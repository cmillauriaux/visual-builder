# 027 — Slider CFG pour la génération IA

## Contexte

Le workflow ComfyUI utilise un `CFGGuider` (node `75:63`) dont la valeur `cfg` contrôle la fidélité au prompt. Une valeur basse (1) donne plus de liberté créative, une valeur haute (10+) suit plus fidèlement le prompt.

## Critères d'acceptation

1. `build_workflow()` accepte un paramètre `cfg: float = 1.0` et l'injecte dans `wf["75:63"]["inputs"]["cfg"]`.
2. `generate()` accepte un paramètre `cfg: float = 1.0` et le transmet à `build_workflow()`.
3. L'onglet IA du dialog `ImagePickerDialog` affiche un slider CFG (HSlider) :
   - Range : 1.0 à 30.0
   - Step : 0.5
   - Valeur par défaut : 1.0
   - Un label affiche la valeur courante du slider
4. Le slider est placé entre le prompt et le bouton "Générer".
5. La valeur du slider est passée à `_ia_client.generate()` lors du clic sur "Générer".
6. Tests couvrant :
   - `test_build_workflow_sets_cfg_value` : la valeur CFG est injectée dans le workflow
   - `test_build_workflow_default_cfg_is_1` : la valeur par défaut est 1.0
   - `test_image_picker_has_cfg_slider` : le slider est présent dans l'onglet IA
