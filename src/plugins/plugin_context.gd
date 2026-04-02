# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

class_name PluginContext
extends RefCounted

## Current story model (may be null if no story is loaded)
var story = null

## Absolute path to the story directory
var story_base_path: String = ""

## Currently active chapter (may be null)
var current_chapter = null

## Currently active scene (may be null)
var current_scene = null

## Currently active sequence (may be null)
var current_sequence = null

## Reference to the main editor node — used by plugins to add_child dialogs etc.
## Must be non-null before a plugin callback is invoked.
var main_node: Control = null