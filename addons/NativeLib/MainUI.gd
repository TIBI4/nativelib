tool
extends Control

const package_info = preload('res://addons/NativeLib/package_info.tscn')
const _global_nativelib := '/usr/local/bin/nativelib'
const _local_nativelib := 'addons/NativeLib/nativelib'
const _remote_url := 'https://raw.githubusercontent.com/DrMoriarty/nativelib-cli/HEAD/nativelib'

var _STORAGE := {}
var _PROJECT := {}
var _filter := ''
var _NL_GLOBAL := true

signal downloading_complete

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#    pass

func save_data() -> void:
    pass

func check_nativelib() -> bool:
    var f = File.new()
    if f.file_exists('res://'+_local_nativelib):
        _NL_GLOBAL = false
        return true
    if f.file_exists(_global_nativelib):
        _NL_GLOBAL = true
        return true
    return false

func set_editor(editor: EditorPlugin) -> void:
    yield(get_tree(), 'idle_frame')
    if not check_nativelib():
        push_warning('NativeLib not installed in system. Making a local copy...')
        install_local_nativelib()
        yield(self, 'downloading_complete')
        nativelib(['--update'])
    load_storage()
    nativelib(['--prepare'])
    load_project()
    update_system_info()
    update_plugin_list()
    update_status()

func load_storage() -> void:
    var path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
    var storage_path = '%s/../.nativelib/storage'%path
    var f = File.new()
    if f.open(storage_path, File.READ) != OK:
        push_error('NativeLib repository not found!')
        return
    var content = f.get_as_text()
    f.close()
    var result = JSON.parse(content)
    if result.error == OK:
        _STORAGE = result.result
    else:
        push_error('Can not read NativeLib storage. Is it correctly installed?')

func load_project() -> void:
    var f = File.new()
    if f.open('res://.nativelib', File.READ) != OK:
        push_warning('NativeLib not initialized yet')
        return
    var content = f.get_as_text()
    f.close()
    var result = JSON.parse(content)
    if result.error == OK:
        _PROJECT = result.result
    else:
        push_error('Can not read NativeLib project meta data.')

func update_plugin_list() -> void:
    for ch in $view/panel/scroll/margin/list.get_children():
        ch.queue_free()
    for plugin in _STORAGE:
        var info = _STORAGE[plugin]
        var pi = package_info.instance()
        var local = {}
        if 'packages' in _PROJECT:
            if plugin in _PROJECT.packages:
                local = _PROJECT.packages[plugin]
        pi.init_info(info, local)
        pi.connect('install', self, '_on_plugin_install')
        pi.connect('uninstall', self, '_on_plugin_uninstall')
        pi.connect('update', self, '_on_plugin_update')
        $view/panel/scroll/margin/list.add_child(pi)

func get_installed_packages() -> Array:
    var result := []
    if 'packages' in _PROJECT:
        for p in _PROJECT.packages:
            result.append(p)
    return result

func update_system_info() -> void:
    if 'platforms' in _PROJECT:
        $view/status/iOSButton.pressed = 'ios' in _PROJECT.platforms
        $view/status/AndroidButton.pressed = 'android' in _PROJECT.platforms
    else:
        $view/status/iOSButton.pressed = false
        $view/status/AndroidButton.pressed = false
    $view/status/InstallSystemButton.visible = _NL_GLOBAL
    $view/status/UpdateSystemButton.visible = not _NL_GLOBAL
    var output = nativelib(['--version'], false)
    var s = ''
    if _NL_GLOBAL:
        s = 'Global NativeLib'
    else:
        s = 'Local NativeLib'
    $view/status/system.text = '%s %s'%[s, output[0].replace('\n', '')]

func update_status() -> void:
    $view/status/info.text = '%d packages in repository, %d installed'%[_STORAGE.keys().size(), get_installed_packages().size()]

func install_local_nativelib() -> void:
    var http_request = HTTPRequest.new()
    http_request.name = 'HTTP'
    add_child(http_request)
    http_request.connect('request_completed', self, '_http_request_completed')
    var error = http_request.request(_remote_url)
    if error != OK:
        push_error('HTTP error %d. Can not download a local copy of NativeLib'%error)

func _http_request_completed(result, response_code, headers, body) -> void:
    if response_code >= 300:
        push_error('HTTP response code: %d'%response_code)
    else:
        var f = File.new()
        f.open('res://'+_local_nativelib, File.WRITE)
        f.store_buffer(body)
        f.close()
        run_command('chmod', ['+x', _local_nativelib])
        print('Installed %s'%_local_nativelib)
        _NL_GLOBAL = false
    emit_signal('downloading_complete')

func _on_UpdateRepoButton_pressed() -> void:
    nativelib(['--update'])
    load_storage()
    update_plugin_list()
    update_status()

func _on_plugin_install(package: String) -> void:
    nativelib(['--install', package])
    load_project()
    update_plugin_list()
    update_status()
    # install all new android modules
    if 'packages' in _PROJECT:
        for package in _PROJECT.packages:
            var info = _PROJECT.packages[package]
            if 'android_module' in info:
                add_android_module(info.android_module)

func _on_plugin_uninstall(package: String) -> void:
    if package in _PROJECT.packages:
        var local = _PROJECT.packages[package]
        if 'android_module' in local:
            remove_android_module(local.android_module)
    nativelib(['--uninstall', package])
    load_project()
    update_plugin_list()
    update_status()

func _on_plugin_update(package: String) -> void:
    nativelib(['--uninstall', package])
    nativelib(['--install', package])
    load_project()
    update_plugin_list()
    update_status()

func nativelib(params: Array, show_output: bool = true) -> Array:
    return run_command(_global_nativelib if _NL_GLOBAL else _local_nativelib, params, show_output)

func run_command(cmd: String, params: Array, show_output: bool = true) -> Array:
    #print('%s %s'%[cmd, params])
    var output := []
    OS.execute(cmd, params, true, output)
    if show_output:
        for line in output:
            print(line)
    return output

func _on_InstallSystemButton_pressed() -> void:
    install_local_nativelib()
    yield(self, 'downloading_complete')
    update_system_info()

func _on_UpdateSystemButton_pressed() -> void:
    install_local_nativelib()
    yield(self, 'downloading_complete')
    update_system_info()

func _on_AndroidButton_toggled(button_pressed: bool) -> void:
    nativelib(['--android'], false)
    load_project()
    update_system_info()

func _on_iOSButton_toggled(button_pressed: bool) -> void:
    nativelib(['--ios'], false)
    load_project()
    update_system_info()

func remove_android_module(module: String) -> void:
    var modules := []
    if ProjectSettings.has_setting('android/modules'):
        var ms = ProjectSettings.get_setting('android/modules')
        if ms != null and ms != '':
            modules = ms.split(',')
    if module in modules:
        modules.erase(module)
        ProjectSettings.set_setting('android/modules', PoolStringArray(modules).join(','))

func add_android_module(module: String) -> void:
    var modules := []
    if ProjectSettings.has_setting('android/modules'):
        var ms = ProjectSettings.get_setting('android/modules')
        if ms != null and ms != '':
            modules = ms.split(',')
    if not module in modules:
        modules.append(module)
        ProjectSettings.set_setting('android/modules', PoolStringArray(modules).join(','))
