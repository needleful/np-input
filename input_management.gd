@tool
class_name NPInputManager
extends Node

enum PromptMode {
	AutoDetect,
	Keyboard,
	# Unknown gamepad
	GenericGamepad,
	# XBox buttons
	XBox,
	Playstation,
	# Gamecube/Switch-style buttons
	Nintendo
}

const INPUT_EPSILON := 0.1
var input_buffer:Dictionary[String, float] = {}

@export var prompt_mode := PromptMode.AutoDetect
# Swap A/B and X/Y input when using a Nintendo controller
# TODO: implement
@export var nintendo_swap := false

@export_group('Custom Paths', 'custom_')
@export_dir var custom_play_station := ''
@export_dir var custom_x_box := ''
@export_dir var custom_nintendo := ''
@export_dir var custom_generic := ''
@export_dir var custom_keyboard := ''

# device/input event
const f_prompt_path := 'res://addons/np-input/prompts/%s/%s.png'

var prompts := prompt_mode
var gamepad_mode := PromptMode.GenericGamepad

var using_gamepad: bool:
	get:
		return prompts > PromptMode.Keyboard
var allow_input := true

var known_devices: Dictionary[String, PromptMode]

func _ready():
	if Engine.is_editor_hint():
		set_process_input(false)
		return
	# TODO: time_scale_response = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().call_group('input_prompt', '_refresh')

func _input(event: InputEvent):
	# Do not accept input when pressing a button
	if get_viewport().gui_get_focus_owner() and event.is_action_pressed('ui_accept'):
		return
	if allow_input:
		for e in input_buffer.keys():
			if event.is_action_pressed(e) and Input.is_action_just_pressed(e):
				input_buffer[e] = 0.0

	var new_prompts := prompts
	if prompt_mode == PromptMode.AutoDetect:
		if event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.2):
			new_prompts = detect_gamepad_type(event.device)
		elif event is InputEventMouse or event is InputEventKey:
			new_prompts = PromptMode.Keyboard
	else:
		new_prompts = prompt_mode
	if new_prompts != prompts:
		prompts = new_prompts
		_refresh_prompts()

func _refresh_prompts():
	get_tree().call_group('input_prompt', '_refresh')

func _fixed_process(delta: float):
	for e in input_buffer.keys():
		input_buffer[e] += delta

func detect_gamepad_type(device: int) -> PromptMode:
	var type: PromptMode
	var dname := Input.get_joy_name(device).to_lower()
	if dname in known_devices:
		return known_devices[dname]
	if dname.contains('xinput'):
		type = PromptMode.XBox
	elif dname.contains('nintendo'):
		type = PromptMode.Nintendo
	elif dname.begins_with('ps'):
		type = PromptMode.Playstation
	else:
		type = PromptMode.GenericGamepad
	known_devices[dname] = type
	print('New controler: %d (%s: %s)' % [device, dname, PromptMode.keys()[type]])
	gamepad_mode = type
	return type

func set_prompt_mode(mode: int):
	prompt_mode = mode as PromptMode
	if prompt_mode > PromptMode.Keyboard:
		gamepad_mode = prompt_mode
	_refresh_prompts()

func reset(key: String):
	input_buffer[key] = INF

func pressed(action:String):
	if !allow_input:
		return false
	if action in input_buffer:
		var res:bool = input_buffer[action] < INPUT_EPSILON
		input_buffer[action] = INF
		return res
	else:
		return Input.is_action_just_pressed(action)

func released(action:String):
	return Input.is_action_just_released(action)

func holding(action:String) -> bool:
	var i := Input.get_action_strength(action) > 0.0
	return allow_input and i

static func default_input_for_action(action: String, gamepad: bool) -> InputEvent:
	var settings:Dictionary = ProjectSettings['input/'+action]
	if not settings:
		push_error('No such action: ', action)
		return null
	return _first_action(settings.events, gamepad)

static func get_input_for_action_and_mode(action: String, mode: PromptMode) -> InputEvent:
	var g := false
	match mode:
		PromptMode.Keyboard:
			g = false
		_:
			g = true
	return get_input_for_action(action, g)

static func get_input_for_action(action: String, gamepad: bool) -> InputEvent:
	return _first_action(InputMap.action_get_events(action), gamepad)

static func _first_action(list: Array, gamepad: bool) -> InputEvent:
	for event in list:
		if gamepad and (
			event is InputEventJoypadButton
			or event is InputEventJoypadMotion
		):
			return event
		elif !gamepad and (
			event is InputEventKey
			or event is InputEventMouseButton
		):
			return event
	return null

func get_action_input_string(action: String, override = null):
	var gamepad: bool
	if override != null:
		gamepad = override
	else:
		gamepad = using_gamepad

	var input := get_input_for_action(action, gamepad)
	return get_input_string(input)

func get_input_string(input:InputEvent) -> String:
	if input is InputEventJoypadButton:
		return 'gamepad'+str(input.button_index)
	elif input is InputEventJoypadMotion:
		return 'axis'+str(input.axis)
	elif input is InputEventMouseButton:
		return 'mouse'+str(input.button_index)
	elif input is InputEventJoypadMotion:
		return 'axis'+str(input.axis)
	elif input is InputEventKey:
		var keycode = input.physical_keycode
		if !keycode:
			keycode = input.keycode
		var key_str = OS.get_keycode_string(keycode)
		if key_str == '':
			key_str = '<unbound>'
		return key_str
	return str(input)

func load_input_image(input_str: String, mode: PromptMode) -> Texture2D:
	var gamepad: bool
	if mode == PromptMode.AutoDetect:
		mode = prompts
		gamepad = using_gamepad
	var custom_prompt: String
	match mode:
		PromptMode.Keyboard:
			custom_prompt = custom_keyboard
			gamepad = false
		PromptMode.Nintendo:
			custom_prompt = custom_nintendo
			gamepad = true
		PromptMode.Playstation:
			custom_prompt = custom_play_station
			gamepad = true
		PromptMode.XBox:
			custom_prompt = custom_x_box
			gamepad = true
		_:
			custom_prompt = custom_generic
			gamepad = true
	var prompt : String
	if custom_prompt:
		prompt = '%s/%s.png' % [custom_prompt, input_str]
	else:
		var device = 'pad_generic' if gamepad else 'keyboard'
		prompt = f_prompt_path % [device, input_str]
		
	if ResourceLoader.exists(prompt):
		return load(prompt)
	else:
		return null

func get_mouse_zoom_axis() -> float:
	return 15*( float(Input.is_action_just_released('mouse_zoom_in'))
			- float(Input.is_action_just_released('mouse_zoom_out')) )

# Assumes only one action given
func rebind(action: String, input: InputEvent, gamepad: bool):
	var old := get_input_for_action(action, gamepad)
	InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, input)

func translate(action_name: String) -> String:
	return tr('action:'+action_name)
