#!/usr/bin/env bash
set -euo pipefail

# Compile un export template Web personnalisé (WASM léger) pour Godot 4.6.1
# Usage: ./scripts/build_web_template.sh <godot_source_dir> [options]
#
# Prérequis :
#   - Emscripten SDK (emsdk) installé et dans le PATH (version ≥ 3.1.39)
#   - Python 3 + SCons
#   - Code source Godot 4.6.1 (git clone https://github.com/godotengine/godot.git -b 4.6.1-stable)
#   - wasm-opt (optionnel, pour optimisation supplémentaire)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="$SCRIPT_DIR/custom_web_template.py"

GODOT_SRC=""
JOBS=""
SKIP_WASM_OPT=false

usage() {
    cat <<'EOF'
Usage: ./scripts/build_web_template.sh <godot_source_dir> [options]

Compile un export template Web personnalisé avec les modules minimaux.

Arguments:
  godot_source_dir        Chemin vers le code source Godot 4.6.1

Options:
  -j, --jobs N            Nombre de jobs parallèles (défaut: auto)
  --skip-wasm-opt         Ne pas exécuter wasm-opt après la compilation
  -h, --help              Aide

Prérequis:
  - Emscripten SDK activé (source emsdk_env.sh)
  - Python 3 + SCons (pip install scons)
  - wasm-opt (npm install -g binaryen) — optionnel

Exemple:
  source ~/emsdk/emsdk_env.sh
  ./scripts/build_web_template.sh ~/godot-4.6.1
EOF
    exit 0
}

error() {
    echo "ERREUR: $1" >&2
    exit 1
}

info() {
    echo "→ $1"
}

# --- Parsing des arguments ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -j|--jobs) JOBS="$2"; shift 2 ;;
        --skip-wasm-opt) SKIP_WASM_OPT=true; shift ;;
        -*)
            error "Option inconnue : $1"
            ;;
        *)
            if [[ -z "$GODOT_SRC" ]]; then
                GODOT_SRC="$1"
            else
                error "Argument inattendu : $1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$GODOT_SRC" ]]; then
    error "Le chemin vers le code source Godot est requis. Voir --help."
fi

# Résoudre en chemin absolu
GODOT_SRC="$(cd "$GODOT_SRC" && pwd)"

# --- Vérifications ---

if [[ ! -f "$GODOT_SRC/SConstruct" ]]; then
    error "SConstruct introuvable dans $GODOT_SRC. Est-ce bien le code source Godot ?"
fi

if ! command -v scons &>/dev/null; then
    error "scons introuvable. Installez-le : pip install scons"
fi

if ! command -v emcc &>/dev/null; then
    error "emcc introuvable. Activez Emscripten : source <emsdk>/emsdk_env.sh"
fi

if [[ ! -f "$PROFILE" ]]; then
    error "Profil SCons introuvable : $PROFILE"
fi

# --- Compilation ---

info "Code source Godot : $GODOT_SRC"
info "Profil SCons : $PROFILE"

SCONS_ARGS="platform=web target=template_release profile=$PROFILE"
if [[ -n "$JOBS" ]]; then
    SCONS_ARGS="$SCONS_ARGS -j$JOBS"
fi

info "Compilation en cours (cela peut prendre 15-60 minutes)..."
cd "$GODOT_SRC"
scons $SCONS_ARGS

# --- Localiser le template généré ---

# Godot génère le template dans bin/
TEMPLATE_DIR="$GODOT_SRC/bin"
TEMPLATE_ZIP=$(find "$TEMPLATE_DIR" -name "godot.web.template_release.wasm32*.zip" -type f 2>/dev/null | head -1)

if [[ -z "$TEMPLATE_ZIP" ]]; then
    error "Template compilé introuvable dans $TEMPLATE_DIR"
fi

info "Template compilé : $TEMPLATE_ZIP"

# --- wasm-opt (optionnel) ---

if [[ "$SKIP_WASM_OPT" == false ]] && command -v wasm-opt &>/dev/null; then
    info "Optimisation avec wasm-opt..."
    TEMP_UNZIP=$(mktemp -d)
    cd "$TEMP_UNZIP"
    unzip -q "$TEMPLATE_ZIP"

    WASM_FILE=$(find . -name "*.wasm" -type f | head -1)
    if [[ -n "$WASM_FILE" ]]; then
        ORIG_SIZE=$(stat -f%z "$WASM_FILE" 2>/dev/null || stat --printf="%s" "$WASM_FILE" 2>/dev/null)
        wasm-opt "$WASM_FILE" -o "$WASM_FILE" -all --post-emscripten -Oz
        NEW_SIZE=$(stat -f%z "$WASM_FILE" 2>/dev/null || stat --printf="%s" "$WASM_FILE" 2>/dev/null)
        info "wasm-opt : $((ORIG_SIZE / 1024 / 1024)) Mo → $((NEW_SIZE / 1024 / 1024)) Mo"

        # Recréer le zip
        zip -q -r "$TEMPLATE_ZIP" .
    fi
    rm -rf "$TEMP_UNZIP"
elif [[ "$SKIP_WASM_OPT" == false ]]; then
    info "wasm-opt non trouvé — optimisation post-build ignorée"
fi

# --- Copier le template dans le projet ---

OUTPUT_DIR="$PROJECT_DIR/scripts/export_templates"
mkdir -p "$OUTPUT_DIR"
FINAL_NAME="godot.web.template_release.wasm32.zip"
cp "$TEMPLATE_ZIP" "$OUTPUT_DIR/$FINAL_NAME"

info "Template copié dans : scripts/export_templates/$FINAL_NAME"
info ""
info "Pour l'utiliser, le preset web.cfg est déjà configuré."
info "Relancez l'export depuis Godot : Histoire → Exporter → Web"

# Afficher la taille
FINAL_SIZE=$(stat -f%z "$OUTPUT_DIR/$FINAL_NAME" 2>/dev/null || stat --printf="%s" "$OUTPUT_DIR/$FINAL_NAME" 2>/dev/null)
info "Taille du template : $((FINAL_SIZE / 1024 / 1024)) Mo"
