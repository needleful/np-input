@tool
class_name NPInputManager
extends Node

enum PromptMode {
	# Automatically detect what prompts to use
	Auto,
	# Only show gamepad prompts
	Gamepad,
	# Only show keyboard/mouse prompts
	Keyboard
}
# Type of controller detected (for prompting)
enum Gamepad {
	# Unknown gamepad
	Generic,
	# XBox buttons
	XBox,
	Playstation,
	# Gamecube/Switch-style buttons
	Nintendo
}

const INPUT_EPSILON := 0.1
var input_buffer:Dictionary[String, float] = {}

@export var prompt_mode := PromptMode.Auto
# Swap A/B and X/Y input when using a Nintendo controller
# TODO: implement
@export var nintendo_swap := false

var using_gamepad := true
var allow_input := true

func _ready():
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

	var ogg := using_gamepad
	match prompt_mode:
		PromptMode.Gamepad:
			using_gamepad = true
		PromptMode.Keyboard:
			using_gamepad = false
		_:
			if event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.2):
				using_gamepad = true
			elif event is InputEventMouse or event is InputEventKey:
				using_gamepad = false
	if ogg != using_gamepad:
		get_tree().call_group('input_prompt', '_refresh')

func _fixed_process(delta: float):
	for e in input_buffer.keys():
		input_buffer[e] += delta

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

func get_mouse_zoom_axis() -> float:
	return 15*( float(Input.is_action_just_released('mouse_zoom_in'))
			- float(Input.is_action_just_released('mouse_zoom_out')) )
