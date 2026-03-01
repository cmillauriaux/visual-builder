# 030 — Slider Steps pour la génération IA

## Contexte

Le workflow ComfyUI utilise un `Flux2Scheduler` (node `75:62`) dont la valeur `steps` contrôle le nombre d'étapes de débruitage. Plus d'étapes = meilleure qualité mais génération plus lente. La valeur actuelle est fixée à 4.

## Critères d'acceptation

1. `build_workflow()` accepte un paramètre `steps: int = 4` et l'injecte dans `wf["75:62"]["inputs"]["steps"]`.
2. `generate()` accepte un paramètre `steps: int = 4` et le transmet à `build_workflow()`.
3. L'onglet IA du dialog `ImagePickerDialog` affiche un slider Steps (HSlider) :
   - Range : 1 à 50
   - Step : 1
   - Valeur par défaut : 4
   - Un label affiche la valeur courante du slider
4. Le slider est placé entre le slider CFG et le bouton "Générer".
5. La valeur du slider est passée à `_ia_client.generate()` lors du clic sur "Générer".
6. Tests couvrant :
   - `test_build_workflow_sets_steps_value` : la valeur steps est injectée dans le workflow
   - `test_build_workflow_default_steps_is_4` : la valeur par défaut est 4
