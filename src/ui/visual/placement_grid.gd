# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Logique de grille de placement et de snapping pour les foregrounds.
## Divise le background en `divisions` x `divisions` cellules.

var divisions: int = 12

## Retourne les positions Y des lignes horizontales en pixels.
func get_horizontal_lines(bg_size: Vector2) -> Array:
	var lines := []
	for i in range(divisions + 1):
		lines.append(float(i) * bg_size.y / float(divisions))
	return lines

## Retourne les positions X des lignes verticales en pixels.
func get_vertical_lines(bg_size: Vector2) -> Array:
	var lines := []
	for i in range(divisions + 1):
		lines.append(float(i) * bg_size.x / float(divisions))
	return lines

## Retourne tous les points de snap en coordonnées normalisées (0-1).
## Inclut les intersections (13x13) et les centres des cellules (12x12).
func get_snap_points(_bg_size: Vector2) -> Array:
	var points := []
	var d := float(divisions)

	# Intersections: (divisions+1) x (divisions+1)
	for iy in range(divisions + 1):
		for ix in range(divisions + 1):
			points.append(Vector2(float(ix) / d, float(iy) / d))

	# Cell centers: divisions x divisions
	for iy in range(divisions):
		for ix in range(divisions):
			points.append(Vector2((float(ix) + 0.5) / d, (float(iy) + 0.5) / d))

	return points

## Snap une position normalisée (anchor_bg) au point de snap le plus proche.
func snap_position(anchor_bg: Vector2, bg_size: Vector2) -> Vector2:
	var clamped = Vector2(clampf(anchor_bg.x, 0.0, 1.0), clampf(anchor_bg.y, 0.0, 1.0))
	var points = get_snap_points(bg_size)
	var best: Vector2 = clamped
	var best_dist: float = INF
	for p in points:
		var dist = clamped.distance_squared_to(p)
		if dist < best_dist:
			best_dist = dist
			best = p
	return best