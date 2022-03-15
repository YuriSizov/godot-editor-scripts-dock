@tool
extends EditorPlugin

var dock_scene : Control
var embedded_controls : Array = []

func _enter_tree() -> void:
	dock_scene = load("res://addons/editor-scripts-dock/Dock.tscn").instance()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UR, dock_scene)
	dock_scene.script_selected.connect(_on_script_selected_in_dock)
	dock_scene.script_create_requested.connect(_on_script_create_requested)
	dock_scene.script_locate_requested.connect(_on_script_locate_requested)
	
	var editor_settings = get_editor_interface().get_editor_settings()
	dock_scene.set_editor_settings(editor_settings)
	
	var script_editor = get_editor_interface().get_script_editor()
	script_editor.editor_script_changed.connect(_on_editor_script_changed)
	script_editor.script_close.connect(_on_editor_script_close)
	
	_update_script_list()
	_update_script_label()
	_hide_script_panel()

func _exit_tree() -> void:
	remove_control_from_docks(dock_scene)
	dock_scene.queue_free()
	
	for control in embedded_controls:
		if (is_instance_valid(control) && control.is_inside_tree()):
			var parent = control.get_parent()
			parent.remove_child(control)
		control.queue_free()

# Script list changes
func _update_script_list(exclude_script : Script = null) -> void:
	var script_editor = get_editor_interface().get_script_editor()
	var open_script_list = script_editor.get_open_scripts()
	
	var script_list := []
	for script in open_script_list:
		if (exclude_script != null && script == exclude_script):
			continue
		script_list.append(script)
	
	dock_scene.set_open_scripts(script_list)
	dock_scene.select_script(script_editor.get_current_script())

func _on_editor_script_changed(active_script : Script) -> void:
	await get_tree().idle_frame
	_update_script_list()
	_update_script_label()

func _on_editor_script_close(closed_script : Script) -> void:
	await get_tree().idle_frame
	_update_script_list(closed_script)

func _on_script_selected_in_dock(active_script : Script) -> void:
	get_editor_interface().edit_resource(active_script)

func _on_script_create_requested() -> void:
	get_editor_interface().get_script_editor().open_script_create_dialog("Object", "res://new_script")

func _on_script_locate_requested(active_script : Script) -> void:
	var path_to_locate = active_script.resource_path
	get_editor_interface().select_file(path_to_locate)

# File path label
func _update_script_label() -> void:
	var script_editor = get_editor_interface().get_script_editor()
	var script_editor_tab_container = script_editor.get_child(0).get_child(1).get_child(1)
	#var script_editor_tabs = script_editor_tab_container.get_children()
	
	var tab_index = script_editor_tab_container.current_tab
	if (script_editor_tab_container.get_child_count() <= tab_index):
		return
	var script_tab = script_editor_tab_container.get_child(script_editor_tab_container.current_tab)
	
	if (script_tab.get_class() == "ScriptTextEditor"):
		var tab_status_bar = script_tab.get_child(0).get_child(0).get_child(2)
		
		var script_path_label = tab_status_bar.get_child(4)
		if (script_path_label.name != "ScriptPathLabel"):
			script_path_label = Label.new()
			script_path_label.name = "ScriptPathLabel"
			script_path_label.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
			
			var label_color = get_editor_interface().get_base_control().get_color("contrast_color_2", "Editor")
			script_path_label.add_color_override("font_color", label_color)
			
			tab_status_bar.add_child_below_node(tab_status_bar.get_child(3), script_path_label)
			embedded_controls.append(script_path_label)
		
		var current_script = script_editor.get_current_script()
		if (current_script):
			script_path_label.text = current_script.resource_path
		else:
			script_path_label.text = ""

# Script panel in editor
func _hide_script_panel() -> void:
	var script_editor = get_editor_interface().get_script_editor()
	var script_panel = script_editor.get_child(0).get_child(1).get_child(0)
	script_panel.hide()
