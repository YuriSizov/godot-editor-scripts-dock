@tool
extends Control

# Node references
@onready var filter_scripts : LineEdit = $Layout/FilterScripts
@onready var script_list : ItemList = $Layout/ScriptList
@onready var create_script_button : ToolButton = $Layout/Controls/CreateScriptButton
@onready var locate_script_button : ToolButton = $Layout/Controls/LocateScriptButton

# Public properties
var editor_settings : EditorSettings #setget set_editor_settings
var scripts : Array = [] # of Script

# Private properties
var filter_value : String = ""

var setting_sort_scripts_by
var setting_list_script_names_as

enum SORT_SCRIPTS_BY { NAME, PATH, NONE }
enum LIST_SCRIPT_NAMES_AS { NAME, PARENT_AND_NAME, FULL_PATH }

signal script_selected(active_script)
signal script_create_requested()
signal script_locate_requested(active_script)

func _ready() -> void:
	_update_theme()
	
	filter_scripts.placeholder_text = "Filter scripts"
	filter_scripts.clear_button_enabled = true
	filter_scripts.right_icon = EditorSettings.get_icon("Search", "EditorIcons")
	filter_scripts.connect("text_changed", self, "_on_filter_scripts_changed")
	
	script_list.clear()
	script_list.connect("item_selected", self, "_on_script_selected")
	
	create_script_button.connect("pressed", self, "_on_create_button_pressed")
	locate_script_button.connect("pressed", self, "_on_locate_button_pressed")

func _update_theme() -> void:
	if (!Engine.editor_hint || !is_inside_tree()):
		return
	
	create_script_button.icon = get_icon("ScriptCreate", "EditorIcons")
	locate_script_button.icon = get_icon("Filesystem", "EditorIcons")

### Helpers
func _update_script_list() -> void:
	clear_scripts()
	
	var sorted_scripts = Array(scripts)
	sorted_scripts.sort_custom(self, "_sort_scripts")
	
	for script in sorted_scripts:
		var script_path = script.resource_path.trim_prefix("res://")
		if (filter_value != "" && script_path.findn(filter_value) < 0):
			continue
		add_script(script)

func _sort_scripts(a : Script, b : Script) -> bool:
	var a_path = a.resource_path
	var a_name = a.resource_name if !a.resource_name.empty() else a_path.get_file()
	var b_path = b.resource_path
	var b_name = b.resource_name if !b.resource_name.empty() else b_path.get_file()
	
	match(setting_sort_scripts_by):
		SORT_SCRIPTS_BY.NAME:
			return (a_name.to_lower() < b_name.to_lower())
		
		SORT_SCRIPTS_BY.PATH:
			return (a_path < b_path)
		
		SORT_SCRIPTS_BY.NONE:
			return false
	
	return false

func _format_script_text(script : Script, is_changed : bool = false) -> String:
	var script_text = ""
	var script_path = script.resource_path
	var script_name = script.resource_name if !script.resource_name.empty() else script_path.get_file()
	
	match (setting_list_script_names_as):
		LIST_SCRIPT_NAMES_AS.NAME:
			script_text = script_name
		
		LIST_SCRIPT_NAMES_AS.PARENT_AND_NAME:
			var parent_file = script_path.get_base_dir().get_file()
			if (!parent_file.empty()):
				script_text = parent_file.plus_file(script_name)
			else:
				script_text = script_name
		
		LIST_SCRIPT_NAMES_AS.FULL_PATH:
			script_text = script_path
	
	if (is_changed):
		script_text += "(*)"
	
	return script_text

### Properties
func set_editor_settings(value : EditorSettings) -> void:
	if (editor_settings && is_instance_valid(editor_settings)):
		editor_settings.disconnect("settings_changed", self, "_on_editor_settings_changed")
	
	editor_settings = value
	_on_editor_settings_changed()
	editor_settings.connect("settings_changed", self, "_on_editor_settings_changed")

func get_selected_script() -> Script:
	var selection = script_list.get_selected_items()
	if (selection.size() == 0):
		return null
	return script_list.get_item_metadata(selection[0])

func set_open_scripts(open_scripts : Array) -> void:
	scripts = open_scripts
	_update_script_list()

### Public methods
func clear_scripts() -> void:
	script_list.clear()

func add_script(script : Script) -> void:
	var script_icon = load("res://addons/editor-scripts-dock/assets/editor-script.png")
	if (script.get_instance_base_type() == "Resource"):
		script_icon = load("res://addons/editor-scripts-dock/assets/editor-resource.png")
	
	script_list.add_item(_format_script_text(script), script_icon)
	
	var item_index = script_list.get_item_count() - 1
	script_list.set_item_metadata(item_index, script)
	if (script.is_tool()):
		script_list.set_item_icon_modulate(item_index, get_color("accent_color", "Editor"))
	
	# Does not seem to get triggered normally. This is a generic signal and each
	# resource type has to implement it in its own way. There is no other signal,
	# as there is no signal for saving. Needs a PR.
	if (!script.is_connected("changed", self, "_on_script_source_changed")):
		script.connect("changed", self, "_on_script_source_changed", [ item_index ])

func select_script(active_script : Script) -> void:
	if (!active_script):
		return
	
	script_list.unselect_all()
	#script_list.grab_focus()
	
	var script_count = script_list.get_item_count()
	var current_index = 0
	while (current_index < script_count):
		var script = script_list.get_item_metadata(current_index)
		if (script == active_script):
			script_list.select(current_index)
			break
		
		current_index += 1

### Event handlers
func _on_editor_settings_changed() -> void:
	setting_sort_scripts_by = editor_settings.get_setting("text_editor/script_list/sort_scripts_by")
	setting_list_script_names_as = editor_settings.get_setting("text_editor/script_list/list_script_names_as")
	
	var current_script = get_selected_script()
	_update_script_list()
	select_script(current_script)

func _on_script_selected(item_index : int) -> void:
	var script_item = script_list.get_item_metadata(item_index)
	emit_signal("script_selected", script_item)

func _on_script_source_changed(item_index : int) -> void:
	var script_item = script_list.get_item_metadata(item_index)
	script_list.set_item_text(item_index, _format_script_text(script_item, true))

func _on_filter_scripts_changed(value : String) -> void:
	filter_value = value
	
	var current_script = get_selected_script()
	_update_script_list()
	select_script(current_script)

func _on_create_button_pressed() -> void:
	emit_signal("script_create_requested")

func _on_locate_button_pressed() -> void:
	var selected_items = script_list.get_selected_items()
	if (selected_items.size() == 0):
		return
	
	var selected_index = selected_items[0]
	var script_item = script_list.get_item_metadata(selected_index)
	emit_signal("script_locate_requested", script_item)
