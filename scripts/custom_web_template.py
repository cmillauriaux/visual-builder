# custom_web_template.py — Profil SCons pour compiler un export template Web léger
# Usage: scons platform=web profile=custom_web_template.py
#
# Ce profil désactive tous les modules inutilisés par le visual novel 2D
# pour réduire la taille du .wasm (~42 Mo → ~17-20 Mo).

target = "template_release"
optimize = "size"
lto = "full"

# Désactiver la 3D (le jeu est 100% 2D)
disable_3d = "yes"

# GUI avancées requises (RichTextLabel, AcceptDialog sont utilisés par le jeu)
# GraphEdit/CodeEdit ne sont PAS utilisés dans le jeu exporté mais font partie du même module
disable_advanced_gui = "no"

# Text server : le fallback suffit pour du texte latin/français
module_text_server_adv_enabled = "no"
module_text_server_fb_enabled = "yes"

# Pas de Vulkan (GL Compatibility uniquement)
vulkan = "no"
use_volk = "no"
openxr = "no"

# Pas de code déprécié
deprecated = "no"

# Désactiver minizip (pas besoin de décompression ZIP)
minizip = "no"

# Approche sélective : tout désactiver puis activer ce qu'on utilise
modules_enabled_by_default = "no"

# Modules requis par le jeu
module_gdscript_enabled = "yes"       # Langage de script
module_freetype_enabled = "yes"       # Rendu de polices
module_jpg_enabled = "yes"            # Images JPEG (story assets)
module_webp_enabled = "yes"           # WebP (format interne des .ctex importées)
module_svg_enabled = "yes"            # SVG (icônes)
module_regex_enabled = "yes"          # RegEx (story_notification.gd)
module_mp3_enabled = "yes"            # Audio MP3
module_minimp3_enabled = "yes"        # Décodeur MP3
module_ogg_enabled = "yes"            # Conteneur OGG
module_vorbis_enabled = "yes"         # Audio OGG Vorbis
