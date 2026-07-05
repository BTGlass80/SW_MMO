extends SceneTree

var _failures = []

func _init() -> void:
	var bazaar_model_script := load("res://scripts/rules/bazaar_model.gd")
	var bazaar_model = bazaar_model_script.new()
	
	var mock_item := {
		"id": "item_12345",
		"template_key": "medpac",
		"name": "Basic Medpac (Q: 85%)",
		"quality": 85.0,
		"condition": 5,
		"max_condition": 5
	}
	
	var listings := {}
	
	# Test 1: Valid listing deduction and fee computation
	var list_outcome = bazaar_model.list_item(listings, mock_item, 500, "seller_1", 100)
	_assert_equal(bool(list_outcome.get("ok", false)), true, "Valid listing succeeds")
	_assert_equal(int(list_outcome.get("fee", 0)), 25, "Listing fee is 5% of 500 credits (25)")
	
	var next_listings: Dictionary = list_outcome.get("listings", {})
	_assert_equal(next_listings.size(), 1, "One listing added to bazaar map")
	
	var listing_id: String = next_listings.keys()[0]
	var listing: Dictionary = next_listings[listing_id]
	_assert_equal(int(listing.get("price", 0)), 500, "Listing price is 500 credits")
	_assert_equal(listing.get("seller_id", ""), "seller_1", "Seller ID matches")
	_assert_equal(listing.get("item", {}).get("id", ""), "item_12345", "Item ID inside listing matches listed item")

	# Test 2: Listing fails if seller cannot afford the fee
	var poor_list = bazaar_model.list_item(listings, mock_item, 500, "seller_1", 5) # only 5 credits, fee is 25
	_assert_equal(bool(poor_list.get("ok", false)), false, "Listing fails if seller cannot afford listing fee")
	_assert_equal(poor_list.get("reason", ""), "insufficient_credits_for_fee", "Fails with fee reason")

	# Test 3: Buy item validation
	var buy_outcome = bazaar_model.buy_item(next_listings, listing_id, "buyer_1", 1000)
	_assert_equal(bool(buy_outcome.get("ok", false)), true, "Buying item listing succeeds")
	_assert_equal(int(buy_outcome.get("price", 0)), 500, "Buyer pays 500 credits")
	_assert_equal(buy_outcome.get("item", {}).get("id", ""), "item_12345", "Buyer receives the correct item instance")
	_assert_equal(buy_outcome.get("seller_id", ""), "seller_1", "Credits should route to seller_1")
	
	var after_listings: Dictionary = buy_outcome.get("listings", {})
	_assert_equal(after_listings.size(), 0, "Bazaar listing is removed after successful purchase")

	# Test 4: Buy fails if buyer cannot afford listing price
	var poor_buy = bazaar_model.buy_item(next_listings, listing_id, "buyer_1", 100) # only 100 credits, price is 500
	_assert_equal(bool(poor_buy.get("ok", false)), false, "Buying fails if buyer has insufficient credits")
	_assert_equal(poor_buy.get("reason", ""), "insufficient_credits", "Fails with insufficient_credits reason")

	# Test 5: Cancel listing success
	var cancel_outcome = bazaar_model.cancel_listing(next_listings, listing_id, "seller_1")
	_assert_equal(bool(cancel_outcome.get("ok", false)), true, "Cancel listing succeeds for owner")
	_assert_equal(cancel_outcome.get("item", {}).get("id", ""), "item_12345", "Cancel returns the item to owner")
	
	var cancelled_listings: Dictionary = cancel_outcome.get("listings", {})
	_assert_equal(cancelled_listings.size(), 0, "Bazaar listing is removed after cancellation")
	
	# Test 6: Cancel listing unauthorized
	var unauthorized_cancel = bazaar_model.cancel_listing(next_listings, listing_id, "buyer_1")
	_assert_equal(bool(unauthorized_cancel.get("ok", false)), false, "Cancel listing fails for non-owner")
	_assert_equal(unauthorized_cancel.get("reason", ""), "unauthorized", "Fails with unauthorized reason")

	if _failures.is_empty():
		print("bazaar_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual, expected, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
