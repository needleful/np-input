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
	return type

func set_prompt_mode(mode: int):
	prompt_mode = mode as PromptMode

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

func holding(action:String):
	var i := Input.get_action_strength(action) > 0.0
	return allow_input and i

func get_action_input_string(action: String, override = null):
	var gamepad
	if override != null:
		gamepad = override
	else:
		gamepad = using_gamepad
		
	var input: InputEvent
	for event in InputMap.action_get_events(action):
		if gamepad and (
			event is InputEventJoypadButton
			or event is InputEventJoypadMotion
		):
			input = event
			break

		elif !gamepad and (
			event is InputEventKey
			or event is InputEventMouseButton
		):
			input = event
			break
	
	if input is InputEventKey:
		var keycode = input.physical_keycode
		if !keycode:
			keycode = input.keycode
		var key_str = OS.get_keycode_string(keycode)
		if key_str == '':
			key_str = '<unbound>'
		return key_str

	return get_input_string(input)

func get_input_string(input:InputEvent):
	if input is InputEventJoypadButton:
		return 'gamepad'+str(input.button_index)
	elif input is InputEventJoypadMotion:
		return 'axis'+str(input.axis)
	elif input is InputEventMouseButton:
		return 'mouse'+str(input.button_index)
	elif input is InputEventJoypadMotion:
		return 'axis'+str(input.axis)
	return str(input)

func load_input_image(input_str: String) -> Texture2D:
	var custom_prompt: String
	match prompts:
		PromptMode.Keyboard:
			custom_prompt = custom_keyboard
		PromptMode.Nintendo:
			custom_prompt = custom_nintendo
		PromptMode.Playstation:
			custom_prompt = custom_play_station
		PromptMode.XBox:
			custom_prompt = custom_x_box
		_:
			custom_prompt = custom_generic
	var prompt : String
	if custom_prompt:
		prompt = '%s/%s.png' % [custom_prompt, input_str]
	else:
		var device = 'pad_generic' if using_gamepad else 'keyboard'
		prompt = f_prompt_path % [device, input_str]
		
	if ResourceLoader.exists(prompt):
		return load(prompt)
	else:
		return null

func get_mouse_zoom_axis() -> float:
	return 15*( float(Input.is_action_just_released('mouse_zoom_in'))
			- float(Input.is_action_just_released('mouse_zoom_out')) )
