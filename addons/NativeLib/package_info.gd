tool
extends Control

signal install(package)
signal uninstall(package)
signal update(package)

var _info : Dictionary = {}
var _local : Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#    pass

func init_info(info: Dictionary, local: Dictionary) -> void:
    _info = info
    _local = local
    $box/left/name.text = info.name
    $box/left/version.text = 'Latest: %s'%info.latest_version
    var installed := false
    var latest := false
    if 'version' in _local:
        $box/left/box/installed.text = 'Installed: %s'%local.version
        installed = true
        latest = local.version == info.latest_version
        $box/left/box/android.visible = 'android' in local.platforms
        $box/left/box/ios.visible = 'ios' in local.platforms
    else:
        $box/left/box/installed.text = 'Not installed'
        $box/left/box/android.visible = false
        $box/left/box/ios.visible = false
    $box/right/description.text = info.description
    $box/right/controls/InstallButton.visible = not installed
    $box/right/controls/UpdateButton.visible = not latest and installed
    $box/right/controls/UninstallButton.visible = installed

func _on_InstallButton_pressed() -> void:
    emit_signal('install', _info.name)

func _on_UninstallButton_pressed() -> void:
    emit_signal('uninstall', _info.name)

func _on_UpdateButton_pressed() -> void:
    emit_signal('update', _info.name)
