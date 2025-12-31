@tool
class_name InputPrompt
extends Control

@export var action: String: set = set_action
@export_range(0.1, 2.0) var image_scale := 1.0
# For backwards-compatibility
@export var small := false

var default_size := Vector2(64, 64)

const IG = InputManagement.Gamepad
# Any inputs that require translated text
const required_text = {
	IG.Playstation: {
		'gamepad4':'Share',
		'gamepad6':'Options',
		'gamepad9':'L1',
		'gamepad10':'R1',
		'axis4':'L2',
		'axis5':'R2',
	},
	IG.Nintendo: {
		'gamepad4':'Minus (-)',
		'gamepad6':'Plus (+)',
		'gamepad9':'L',
		'gamepad10':'R',
		'axis4':'ZL',
		'axis5':'ZR',
	},
	IG.Generic: {
		'gamepad4':'Select',
		'gamepad6':'Start',
		'gamepad7':'LS',
		'gamepad8':'RS',
		'gamepad9':'LB',
		'gamepad10':'RB',
		'axis4':'LT',
		'axis5':'RT',
	}
}

func _ready():
	default_size = size
	connect('visibility_changed', Callable(self, '_refresh'))

func _refresh():
	set_action(action)

func set_action(a):
	action = a
	if !is_inside_tree():
		return
	elif Engine.is_editor_hint():
		show_text(a)
		return
	elif action == '':
		$image_prompt.hide()
		$key_prompt.hide()
		return

	if !InputMap.has_action(action):
		print_debug('MISSING_ACTION: ', action, ' FOR NODE: ', get_path())
		show_text(action)
		return
	
	var input_str = InputManagement.get_action_input_string(action)
	var img := InputManagement.load_input_image(input_str)
	if img:
		var extra_text := ''
		if InputManagement.using_gamepad:
			var gc := InputManagement.gamepad_type
			if input_str in required_text[gc]:
				extra_text = required_text[gc][input_str]
			elif input_str in required_text[IG.Generic]:
				extra_text = required_text[IG.Generic][input_str]
		show_image(img, extra_text)
	else:
		show_text(input_str)

func show_image(image: Texture2D, extra_text:= ''):
	$key_prompt.hide()
	$image_prompt.show()
	$image_prompt/texture.texture = image
	var c :Label = $image_prompt/custom_text
	if extra_text:
		c.show()
		c.text = '['+tr(extra_text, 'button')+']'
	else:
		c.hide()
	var s = image.get_size()
	if small:
		s /= 3
	s *= image_scale
	size = s
	$image_prompt/texture.custom_minimum_size = s

func show_text(text):
	$image_prompt.hide()
	$key_prompt.show()
	$key_prompt/Label.text = text
	var s := default_size
	if small:
		s = Vector2(48,48)
	s *= image_scale
	$key_prompt.custom_minimum_size = s
	$key_prompt.size = s
	size = s
