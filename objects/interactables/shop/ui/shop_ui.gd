extends Control

const QUALITY_STAR = preload("res://ui_assets/misc/quality_star.png")
const QUALITY_STAR_UNFILLED = preload("res://ui_assets/misc/quality_star_unfilled.png")

@onready var item_label: Label = %ItemLabel
@onready var price_label: Label = %PriceLabel
@onready var buy_button: GeneralButton = %BuyButton
@onready var exit_button: GeneralButton = %ExitButton
@onready var star_container := %StarContainer
@onready var sale_label: Label = %SaleLabel

signal s_purchase
signal s_exit
signal s_left_pressed
signal s_right_pressed


func set_item(item: Item, price: int, discounted := false) -> void:
	buy_button.disabled = false
	buy_button.material.set_shader_parameter(&"alpha", 1.0)
	if not can_afford(price):
		buy_button.disabled = true
		buy_button.material.set_shader_parameter(&"alpha", 0.5)

	%DescPanel.hide()
	if not item:
		item_label.set_text("SOLD OUT!")
		price_label.set_text("")
		sale_label.hide()
		buy_button.disabled = true
		buy_button.material.set_shader_parameter(&"alpha", 0.5)
	else:
		item_label.set_text(item.item_name)
		price_label.set_text(str(price))
		price_label.label_settings.font_color = Color.DARK_RED if discounted else Color.BLACK
		sale_label.visible = discounted
		sale_label.position = Vector2(57, 48) if price_label.text.length() == 1 else Vector2(75, 48)
		if item.is_acessory or item.force_show_shop_category:
			set_stars(int(item.qualitoon + 1))
			%DescTitle.label_settings.font_size = 22
			%DescTitle.label_settings.font_color = item.shop_category_color
			%DescTitle.text = item.shop_category_title.to_upper()
			while %DescTitle.get_line_count() >= 3 and %DescTitle.label_settings.font_size > 1:
				%DescTitle.label_settings.font_size -= 1
			%DescLabel.text = "\"%s\"" % item.item_description
			%DescPanel.show()

func set_stars(stars: int):
	for i in star_container.get_child_count():
		if i < stars:
			star_container.get_child(i).texture = QUALITY_STAR
		else:
			star_container.get_child(i).texture = QUALITY_STAR_UNFILLED

func exit_pressed() -> void:
	s_exit.emit()

func buy_pressed() -> void:
	s_purchase.emit()

func left_pressed() -> void:
	s_left_pressed.emit()

func right_pressed() -> void:
	s_right_pressed.emit()

func get_wallet() -> int:
	if not Util.get_player():
		return 0
	return Util.get_player().stats.money

func can_afford(price: int) -> bool:
	return get_wallet() >= price and not price == -1

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return

	if Input.is_action_just_pressed("move_left"):
		left_pressed()
	elif Input.is_action_just_pressed("move_right"):
		right_pressed()
