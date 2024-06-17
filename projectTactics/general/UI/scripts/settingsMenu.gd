extends GridContainer

signal volumeChanged

func _ready():
	refreshSettings()
	FM.globalLoaded.connect(refreshSettings)

func refreshSettings():
	%musicSlider.value = FM.loadedGlobalData.musicVolume
	%combatSlider.value = FM.loadedGlobalData.combatVolume
	%uiSlider.value = FM.loadedGlobalData.uiVolume
	%ambientSlider.value = FM.loadedGlobalData.ambientVolume
	
	%fullscreenButton.button_pressed = FM.loadedGlobalData.fullscreenToggled
	%vsyncButton.button_pressed = FM.loadedGlobalData.vsyncToggled

func audioPressed():
	%audioMenu.visible = true
	%graphicsMenu.visible = false
	%keybindsMenu.visible = false
	%audioSettingsButton.self_modulate.a = 0.75
	%graphicsSettingsButton.self_modulate.a = 1
	%keybindsSettingsButton.self_modulate.a = 1

func graphicsPressed():
	%audioMenu.visible = false
	%graphicsMenu.visible = true
	%keybindsMenu.visible = false
	%audioSettingsButton.self_modulate.a = 1
	%graphicsSettingsButton.self_modulate.a = 0.75
	%keybindsSettingsButton.self_modulate.a = 1

func keybindsPressed():
	%audioMenu.visible = false
	%graphicsMenu.visible = false
	%keybindsMenu.visible = true
	%audioSettingsButton.self_modulate.a = 1
	%graphicsSettingsButton.self_modulate.a = 1
	%keybindsSettingsButton.self_modulate.a = 0.75

func musicAudioUpdated(newValue):
	Music.changeVolume(4 * newValue - 20)
	FM.loadedGlobalData.musicVolume = newValue
	FM.saveGlobal()
	emit_signal("volumeChanged")

func combatAudioUpdated(newValue):
	FM.loadedGlobalData.combatVolume = newValue
	FM.saveGlobal()
	emit_signal("volumeChanged")

func uiAudioUpdated(newValue):
	SFX.changeVolume(4 * newValue - 20)
	FM.loadedGlobalData.uiVolume = newValue
	FM.saveGlobal()
	emit_signal("volumeChanged")

func ambientAudioUpdated(newValue):
	FM.loadedGlobalData.ambientVolume = newValue
	FM.saveGlobal()
	emit_signal("volumeChanged")

func resetAudioPressed():
	%musicSlider.value = 5
	%combatSlider.value = 5
	%uiSlider.value = 5
	%ambientSlider.value = 5

func fullscreenToggled(toggled_on):
	FM.loadedGlobalData.fullscreenToggled = toggled_on
	FM.saveGlobal()
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func vsyncToggled(toggled_on):
	FM.loadedGlobalData.vsyncToggled = toggled_on
	FM.saveGlobal()
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
