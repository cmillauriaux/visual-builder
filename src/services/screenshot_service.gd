# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Node

## Service de capture d'écran basse résolution pour les sauvegardes.
##
## Utilise un SubViewport miroir à résolution réduite (320×180) pour capturer
## des miniatures sans forcer un flush GPU coûteux sur le viewport principal.

const THUMBNAIL_WIDTH := 320
const THUMBNAIL_HEIGHT := 180

var _sub_viewport: SubViewport
var _main_viewport: Viewport


## Configure le service en attachant un SubViewport miroir au viewport principal.
func setup(main_viewport: Viewport) -> void:
	_main_viewport = main_viewport
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.world_2d = main_viewport.world_2d
	_sub_viewport.transparent_bg = false
	_sub_viewport.handle_input_locally = false
	_sub_viewport.gui_disable_input = true
	add_child(_sub_viewport)


## Capture une miniature depuis le SubViewport miroir.
## Retourne null en mode headless.
func capture() -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	if _sub_viewport == null:
		return null
	return _sub_viewport.get_texture().get_image()