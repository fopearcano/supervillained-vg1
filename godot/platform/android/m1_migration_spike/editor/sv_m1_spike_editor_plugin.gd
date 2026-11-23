@tool
extends EditorPlugin
## THROWAWAY M1 migration spike: adds the spike's Android plugin (a JAR built by
## tools/build_spike_apk.ps1 next to this script) to Android gradle builds and registers it as a
## Godot Android v2 plugin through the manifest meta-data. Enabled only in the scratch export
## project that build_spike_apk.ps1 prepares; the committed project ignores this folder (.gdignore).

var _export_plugin: SpikeExportPlugin


func _enter_tree() -> void:
	_export_plugin = SpikeExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class SpikeExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "SvMigrationSpike"
	const PLUGIN_CLASS := "com.zampano.svspike.MigrationSpikePlugin"
	const JAR := "res://platform/android/m1_migration_spike/editor/bin/sv_m1_migration_spike.jar"

	func _get_name() -> String:
		return PLUGIN_NAME

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform.get_os_name() == "Android"

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([JAR])

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return '<meta-data android:name="org.godotengine.plugin.v2.%s" android:value="%s" />\n' % [PLUGIN_NAME, PLUGIN_CLASS]
