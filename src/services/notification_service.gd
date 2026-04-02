# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Service centralisant les notifications (toasts) dans l'application.
## Permet d'émettre des messages informatifs sans dépendre directement de l'UI principale.

class_name NotificationService

## Émis quand une notification doit être affichée.
signal message_requested(message: String)

## Affiche une notification.
func show_notification(message: String) -> void:
	# L'EventBus est un Autoload, donc accessible globalement.
	EventBus.notification_requested.emit(message)
	message_requested.emit(message) # Garder pour compatibilité locale immédiate