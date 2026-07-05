extends RefCounted

const LISTING_FEE_PCT := 0.05
const MIN_LISTING_FEE := 10

static func generate_listing_id() -> String:
	return String.num_uint64(Time.get_ticks_usec() ^ randi())

static func list_item(listings: Dictionary, item: Dictionary, price: int, seller_id: String, seller_credits: int) -> Dictionary:
	if price <= 0:
		return {"ok": false, "reason": "invalid_price"}
	var fee: int = maxi(MIN_LISTING_FEE, int(price * LISTING_FEE_PCT))
	if seller_credits < fee:
		return {"ok": false, "reason": "insufficient_credits_for_fee", "fee": fee}
		
	var next_listings: Dictionary = listings.duplicate(true)
	var listing_id: String = generate_listing_id()
	var new_listing := {
		"id": listing_id,
		"item": item.duplicate(true),
		"price": price,
		"seller_id": seller_id,
		"created_unix": Time.get_unix_time_from_system()
	}
	next_listings[listing_id] = new_listing
	return {"ok": true, "listings": next_listings, "listing": new_listing, "fee": fee}

static func buy_item(listings: Dictionary, listing_id: String, buyer_id: String, buyer_credits: int) -> Dictionary:
	if not listings.has(listing_id):
		return {"ok": false, "reason": "listing_not_found"}
		
	var listing: Dictionary = listings[listing_id]
	var price: int = int(listing.get("price", 0))
	if buyer_credits < price:
		return {"ok": false, "reason": "insufficient_credits", "price": price}
		
	var next_listings: Dictionary = listings.duplicate(true)
	next_listings.erase(listing_id)
	
	return {
		"ok": true,
		"listings": next_listings,
		"item": listing.get("item", {}).duplicate(true),
		"price": price,
		"seller_id": String(listing.get("seller_id", ""))
	}

static func cancel_listing(listings: Dictionary, listing_id: String, seller_id: String) -> Dictionary:
	if not listings.has(listing_id):
		return {"ok": false, "reason": "listing_not_found"}
		
	var listing: Dictionary = listings[listing_id]
	if String(listing.get("seller_id", "")) != seller_id:
		return {"ok": false, "reason": "unauthorized"}
		
	var next_listings: Dictionary = listings.duplicate(true)
	next_listings.erase(listing_id)
	
	return {
		"ok": true,
		"listings": next_listings,
		"item": listing.get("item", {}).duplicate(true)
	}
