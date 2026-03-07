#!/usr/bin/env bash
set -euo pipefail

# Export d'une histoire en jeu standalone
# Usage: ./scripts/export_story.sh <story_path> [options]

# Ajouter Homebrew au PATH sur macOS au cas où
if [[ "$OSTYPE" == "darwin"* ]]; then
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Valeurs par défaut
OUTPUT_DIR="./build"
PLATFORM="web"
GAME_NAME=""
GODOT_BIN=""
KEEP_TEMP=false
LOG_FILE=""

# Détecter sed (gsed sur macOS si dispo pour compatibilité GNU)
SED_BIN="sed"
if [[ "$OSTYPE" == "darwin"* ]] && command -v gsed &>/dev/null; then
    SED_BIN="gsed"
fi

# --- Fonctions utilitaires ---

usage() {
    cat <<'EOF'
Usage: ./scripts/export_story.sh <story_path> [options]

Exporte une histoire en jeu standalone avec menu et gameplay.

Arguments:
  story_path              Chemin vers le dossier story (user://, absolu, ou res://)

Options:
  -o, --output DIR        Répertoire de sortie (défaut: ./build/)
  -p, --platform PLAT     Plateforme: web, macos, linux, windows, android (défaut: web)
  -n, --name NAME         Nom du fichier exporté (défaut: titre de la story)
  --godot PATH            Chemin vers le binaire Godot
  --keep-temp             Garder le dossier temporaire pour debug
  -h, --help              Aide

Exemples:
  ./scripts/export_story.sh user://stories/mon_histoire
  ./scripts/export_story.sh /chemin/absolu/vers/story -p macos -o ./dist/
  ./scripts/export_story.sh user://stories/aventure -p web -n "Mon Jeu"
EOF
    exit 0
}

error() {
    log "ERREUR: $1"
    exit 1
}

info() {
    log "→ $1"
}

# Écrit dans le log ET sur stdout
log() {
    echo "$1"
    if [[ -n "$LOG_FILE" ]]; then
        echo "$1" >> "$LOG_FILE"
    fi
}

# Exécute une commande en loggant stdout+stderr dans le fichier log
run_logged() {
    if [[ -n "$LOG_FILE" ]]; then
        "$@" 2>&1 | tee -a "$LOG_FILE"
    else
        "$@" 2>&1
    fi
}

# Détecter le binaire Godot
find_godot() {
    if [[ -n "$GODOT_BIN" ]]; then
        if [[ ! -x "$GODOT_BIN" ]]; then
            error "Binaire Godot introuvable : $GODOT_BIN"
        fi
        return
    fi

    # macOS
    if [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
        GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
        return
    fi

    # PATH
    if command -v godot &>/dev/null; then
        GODOT_BIN="$(command -v godot)"
        return
    fi

    error "Godot introuvable. Utilisez --godot pour spécifier le chemin."
}

# Extrait le nom du projet depuis project.godot
get_project_name() {
    grep 'config/name=' "$PROJECT_DIR/project.godot" | "$SED_BIN" 's/config\/name="//;s/"//'
}

# Résout un chemin user:// en chemin OS absolu
resolve_user_path() {
    local path="$1"
    local project_name
    project_name="$(get_project_name)"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "$HOME/Library/Application Support/Godot/app_userdata/$project_name/${path#user://}"
    elif [[ "$OSTYPE" == "linux"* ]]; then
        echo "$HOME/.local/share/godot/app_userdata/$project_name/${path#user://}"
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
        echo "$APPDATA/Godot/app_userdata/$project_name/${path#user://}"
    else
        error "OS non supporté pour la résolution user:// : $OSTYPE"
    fi
}

# Résout story_path en chemin OS absolu
resolve_story_path() {
    local path="$1"

    if [[ "$path" == user://* ]]; then
        resolve_user_path "$path"
    elif [[ "$path" == res://* ]]; then
        echo "$PROJECT_DIR/${path#res://}"
    elif [[ "$path" == /* ]]; then
        echo "$path"
    else
        # Chemin relatif
        echo "$(cd "$(pwd)" && realpath "$path")"
    fi
}

# Extrait le titre de la story depuis story.yaml
get_story_title() {
    local story_dir="$1"
    if [[ -f "$story_dir/story.yaml" ]]; then
        grep '^title:' "$story_dir/story.yaml" | "$SED_BIN" 's/^title: *"//;s/"$//' | head -1
    else
        echo ""
    fi
}

# Extension de sortie selon la plateforme
get_export_extension() {
    case "$PLATFORM" in
        web) echo "html" ;;
        macos) echo "zip" ;;
        linux) echo "x86_64" ;;
        windows) echo "exe" ;;
        android) echo "apk" ;;
        *) error "Plateforme inconnue : $PLATFORM" ;;
    esac
}

# Nom du preset dans le fichier cfg
get_preset_name() {
    case "$PLATFORM" in
        web) echo "Web" ;;
        macos) echo "macOS" ;;
        linux) echo "Linux" ;;
        windows) echo "Windows" ;;
        android) echo "Android" ;;
        *) error "Plateforme inconnue : $PLATFORM" ;;
    esac
}

# --- Parsing des arguments ---

if [[ $# -lt 1 ]]; then
    usage
fi

STORY_PATH_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        -p|--platform) PLATFORM="$2"; shift 2 ;;
        -n|--name) GAME_NAME="$2"; shift 2 ;;
        --godot) GODOT_BIN="$2"; shift 2 ;;
        --keep-temp) KEEP_TEMP=true; shift ;;
        -*)
            error "Option inconnue : $1"
            ;;
        *)
            if [[ -z "$STORY_PATH_ARG" ]]; then
                STORY_PATH_ARG="$1"
            else
                error "Argument inattendu : $1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$STORY_PATH_ARG" ]]; then
    error "story_path est requis. Voir --help."
fi

# Valider la plateforme
case "$PLATFORM" in
    web|macos|linux|windows|android) ;;
    *) error "Plateforme invalide : $PLATFORM. Valeurs: web, macos, linux, windows, android" ;;
esac

# --- Exécution ---

find_godot

# Préparer le dossier de sortie tôt pour y placer le log
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# Créer le fichier de log dans le dossier de sortie
LOG_FILE="$OUTPUT_DIR/export.log"
: > "$LOG_FILE"

log "========================================="
log "  Export story — $(date '+%Y-%m-%d %H:%M:%S')"
log "========================================="
info "Godot : $GODOT_BIN"
info "Plateforme : $PLATFORM"

# 1. Résoudre le chemin story
STORY_DIR="$(resolve_story_path "$STORY_PATH_ARG")"
info "Story : $STORY_DIR"

# 2. Valider que story.yaml existe
if [[ ! -f "$STORY_DIR/story.yaml" ]]; then
    error "story.yaml introuvable dans $STORY_DIR"
fi

# 3. Déterminer le nom du jeu
if [[ -z "$GAME_NAME" ]]; then
    GAME_NAME="$(get_story_title "$STORY_DIR")"
    if [[ -z "$GAME_NAME" ]]; then
        GAME_NAME="Exported Game"
    fi
fi
info "Nom du jeu : $GAME_NAME"

# 4. Créer le dossier temporaire
TEMP_DIR="$(mktemp -d)"
TEMP_PROJECT="$TEMP_DIR/project"
info "Dossier temporaire : $TEMP_DIR"

cleanup() {
    if [[ "$KEEP_TEMP" == false ]]; then
        rm -rf "$TEMP_DIR"
    else
        info "Dossier temporaire conservé : $TEMP_DIR"
    fi
}
trap cleanup EXIT

# 5. Copier le projet (sans .godot, .git, build, .claude)
info "Copie du projet..."
if command -v rsync &>/dev/null; then
    rsync -a \
        --exclude='.godot/' \
        --exclude='.git/' \
        --exclude='build/' \
        --exclude='.claude/' \
        --exclude='specs/' \
        --exclude='addons/gut/' \
        "$PROJECT_DIR/" "$TEMP_PROJECT/"
else
    # Fallback sans rsync (Windows/Git Bash)
    cp -a "$PROJECT_DIR/." "$TEMP_PROJECT/"
    rm -rf "$TEMP_PROJECT/.godot" "$TEMP_PROJECT/.git" "$TEMP_PROJECT/build" \
           "$TEMP_PROJECT/.claude" "$TEMP_PROJECT/specs" "$TEMP_PROJECT/addons/gut"
fi

# 6. Copier la story dans res://story/ (sans artbook pour éviter les doublons)
info "Copie de la story..."
mkdir -p "$TEMP_PROJECT/story"
if command -v rsync &>/dev/null; then
    rsync -a --exclude='artbook/' "$STORY_DIR/" "$TEMP_PROJECT/story/"
else
    cp -a "$STORY_DIR/." "$TEMP_PROJECT/story/"
    rm -rf "$TEMP_PROJECT/story/artbook"
fi

# 6b. Optimiser les fichiers audio pour le web (si ffmpeg est disponible)
if [[ "$PLATFORM" != "web" ]]; then
    info "Optimisation audio ignorée (plateforme: $PLATFORM)"
elif ! command -v ffmpeg &>/dev/null; then
    info "ffmpeg non trouvé — optimisation audio ignorée"
else
    AUDIO_LIST="$TEMP_DIR/audio_files.txt"
    find "$TEMP_PROJECT/story" \( -name "*.mp3" -o -name "*.ogg" -o -name "*.wav" \) > "$AUDIO_LIST" 2>/dev/null
    AUDIO_COUNT=$(wc -l < "$AUDIO_LIST" | tr -d ' ')
    info "Fichiers audio trouvés : $AUDIO_COUNT"
    if [[ "$AUDIO_COUNT" -gt 0 ]]; then
        info "Optimisation de $AUDIO_COUNT fichiers audio (128kbps)..."
        while IFS= read -r audio_file; do
            [[ -z "$audio_file" ]] && continue
            tmp_file="${audio_file}.tmp.mp3"
            info "  → $(basename "$audio_file")"
            if ffmpeg -y -i "$audio_file" -b:a 128k -ac 2 "$tmp_file" -loglevel error 2>&1; then
                mv "$tmp_file" "$audio_file"
            else
                rm -f "$tmp_file"
                info "  ⚠ Échec pour $(basename "$audio_file")"
            fi
        done < "$AUDIO_LIST"
    fi
fi

# 7. Importer les ressources (nécessaire avant le script de réécriture)
info "Import des ressources..."
run_logged "$GODOT_BIN" --headless --path "$TEMP_PROJECT" --import || true

# 7b. Réécrire les chemins images via Godot headless
info "Réécriture des chemins images..."
run_logged "$GODOT_BIN" --headless --path "$TEMP_PROJECT" --script res://src/export/rewrite_runner.gd || \
    error "Échec de la réécriture des chemins"

# 8. Modifier project.godot
info "Configuration de project.godot..."
run_logged "$SED_BIN" -i.bak 's|run/main_scene="res://src/main.tscn"|run/main_scene="res://src/game.tscn"|' "$TEMP_PROJECT/project.godot"
run_logged "$SED_BIN" -i.bak "s|config/name=\"[^\"]*\"|config/name=\"$GAME_NAME\"|" "$TEMP_PROJECT/project.godot"
# Désactiver le plugin GUT pour l'export
run_logged "$SED_BIN" -i.bak '/\[editor_plugins\]/,/^$/d' "$TEMP_PROJECT/project.godot"

# Activer les formats de compression texture requis selon la plateforme
case "$PLATFORM" in
    macos|android)
        # macOS arm64/universal et Android nécessitent ETC2 ASTC
        if ! grep -q '\[rendering\]' "$TEMP_PROJECT/project.godot"; then
            echo -e "\n[rendering]\n" >> "$TEMP_PROJECT/project.godot"
        fi
        # S'assurer que ETC2 ASTC est activé
        if grep -q 'textures/vram_compression/import_etc2_astc' "$TEMP_PROJECT/project.godot"; then
            run_logged "$SED_BIN" -i.bak 's|textures/vram_compression/import_etc2_astc=.*|textures/vram_compression/import_etc2_astc=true|' "$TEMP_PROJECT/project.godot"
        else
            run_logged "$SED_BIN" -i.bak '/^\[rendering\]/a textures/vram_compression/import_etc2_astc=true' "$TEMP_PROJECT/project.godot"
        fi
        ;;
    linux|windows)
        # Desktop nécessite S3TC BPTC (normalement déjà par défaut)
        if ! grep -q '\[rendering\]' "$TEMP_PROJECT/project.godot"; then
            echo -e "\n[rendering]\n" >> "$TEMP_PROJECT/project.godot"
        fi
        if grep -q 'textures/vram_compression/import_s3tc_bptc' "$TEMP_PROJECT/project.godot"; then
            run_logged "$SED_BIN" -i.bak 's|textures/vram_compression/import_s3tc_bptc=.*|textures/vram_compression/import_s3tc_bptc=true|' "$TEMP_PROJECT/project.godot"
        else
            run_logged "$SED_BIN" -i.bak '/^\[rendering\]/a textures/vram_compression/import_s3tc_bptc=true' "$TEMP_PROJECT/project.godot"
        fi
        ;;
esac

# 9. Modifier game.tscn pour définir story_path
info "Configuration de game.tscn..."
run_logged "$SED_BIN" -i.bak '/^script = ExtResource/a story_path = "res://story"' "$TEMP_PROJECT/src/game.tscn"

# Nettoyer les fichiers .bak
find "$TEMP_PROJECT" -name "*.bak" -delete

# 10. Copier le preset d'export
info "Configuration du preset d'export ($PLATFORM)..."
PRESET_FILE="$SCRIPT_DIR/export_presets/$PLATFORM.cfg"
if [[ ! -f "$PRESET_FILE" ]]; then
    error "Preset introuvable : $PRESET_FILE"
fi
run_logged cp "$PRESET_FILE" "$TEMP_PROJECT/export_presets.cfg"

# 11. Préparer le fichier de sortie
EXPORT_EXT="$(get_export_extension)"
PRESET_NAME="$(get_preset_name)"
SAFE_NAME="$(echo "$GAME_NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-')"

if [[ "$PLATFORM" == "web" ]]; then
    EXPORT_DIR="$OUTPUT_DIR/${SAFE_NAME}_web"
    mkdir -p "$EXPORT_DIR"
    EXPORT_FILE="$EXPORT_DIR/index.html"
else
    EXPORT_FILE="$OUTPUT_DIR/${SAFE_NAME}.$EXPORT_EXT"
fi

# 12. Lancer l'export
info "Export en cours ($PLATFORM)..."
run_logged "$GODOT_BIN" --headless --path "$TEMP_PROJECT" --export-release "$PRESET_NAME" "$EXPORT_FILE"
EXPORT_EXIT=$?

if [[ $EXPORT_EXIT -ne 0 ]]; then
    log ""
    log "Godot a retourné le code $EXPORT_EXIT."
    error "L'export a échoué. Consultez le log : $LOG_FILE"
fi

if [[ ! -f "$EXPORT_FILE" ]]; then
    error "L'export semble avoir échoué — fichier non trouvé : $EXPORT_FILE. Consultez le log : $LOG_FILE"
fi

# 13. Découper en PCK par chapitre (web uniquement)
if [[ "$PLATFORM" == "web" ]]; then
    info "Découpage PCK par chapitre..."
    EXPORT_DIR="$(dirname "$EXPORT_FILE")"
    run_logged "$GODOT_BIN" --headless --path "$TEMP_PROJECT" \
        --script res://src/export/pck_chapter_builder.gd \
        -- --output "$EXPORT_DIR"

    if [[ $? -eq 0 ]]; then
        # Ré-exporter le core PCK allégé (sans les assets chapitres supprimés)
        info "Ré-export du core PCK allégé..."
        run_logged "$GODOT_BIN" --headless --path "$TEMP_PROJECT" --export-release "$PRESET_NAME" "$EXPORT_FILE"

        PCK_COUNT=$(find "$EXPORT_DIR" -name "chapter_*.pck" 2>/dev/null | wc -l | tr -d ' ')
        info "$PCK_COUNT PCK chapitres créés"
    else
        info "⚠ Échec du découpage PCK (non bloquant — export monolithique conservé)"
    fi
fi

# 14. Créer le fichier _headers pour Cloudflare Pages (COOP/COEP requis par SharedArrayBuffer)
if [[ "$PLATFORM" == "web" ]]; then
    HEADERS_FILE="$EXPORT_DIR/_headers"
    cat > "$HEADERS_FILE" << 'HEADERS_EOF'
/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
HEADERS_EOF
    info "Fichier _headers créé pour Cloudflare Pages (COOP/COEP)"
fi

log ""
info "Export réussi !"
info "Fichier : $EXPORT_FILE"
info "Log : $LOG_FILE"
if [[ "$PLATFORM" == "web" ]]; then
    info "Pour tester : ouvrir $EXPORT_FILE dans un navigateur (via un serveur local)"
fi
