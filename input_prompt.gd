@tool
extends Control

@export var action: String: set = set_action
@export var small := false
@export var large_font: Font
@export var small_font: Font

var default_size := Vector2(64, 64)

const vis_remap := {
	'axis6':'gamepad6',
	'axis7':'gamepad7'
}

# device/input event
const prompt_path := 'res://ui/prompts/%s/%s.png'

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
		$texture.hide()
		$key_prompt.hide()
		return

	if !InputMap.has_action(action):
		print_debug('MISSING_ACTION: ', action, ' FOR NODE: ', get_path())
		show_text(action)
		return
	
	var input_str = InputManagement.get_action_input_string(action)
	if input_str in vis_remap:
		input_str = vis_remap[input_str]
	var device = 'pad_generic' if InputManagement.using_gamepad else 'keyboard'
	var prompt = prompt_path % [device, input_str]
	if ResourceLoader.exists(prompt):
		var t = load(prompt)
		show_image(t)
	else:
		show_text(input_str)

func show_image(image: Texture2D):
	$key_prompt.hide()
	$texture.show()
	$texture.texture = image
	var s = image.get_size()
	if small:
		s /= 3
	size = s
	$texture.custom_minimum_size = s

func show_text(text):
	$texture.hide()
	$key_prompt.show()
	$key_prompt/Label.text = text
	var s := default_size
	if small:
		s = Vector2(48,48)
	$key_prompt.custom_minimum_size = s
	$key_prompt.size = s
	$key_prompt/Label.add_theme_font_override('font',
		small_font if small else large_font)
	size = s
