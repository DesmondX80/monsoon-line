extends GutTest
## Vaatii GUT-lisäosan (addons/gut). Asennus: Godot Asset Library → "GUT".

var suppression: SuppressionComponent


func before_each() -> void:
	suppression = SuppressionComponent.new()
	add_child_autofree(suppression)


func test_near_miss_raises_suppression() -> void:
	suppression.register_near_miss(0.5)
	assert_gt(suppression.amount, 0.0)


func test_far_miss_is_ignored() -> void:
	suppression.register_near_miss(10.0)
	assert_eq(suppression.amount, 0.0)


func test_amount_is_clamped() -> void:
	for i in 20:
		suppression.register_near_miss(0.0)
	assert_eq(suppression.amount, 1.0)
	assert_true(suppression.is_pinned())
