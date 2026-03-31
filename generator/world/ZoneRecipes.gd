class_name ZoneRecipes
extends RefCounted
## Zone generation recipes. Each function returns a fully populated ZoneResource.
## Registry names are prefixed with "zone_".


static func test_route(rng: RandomNumberGenerator) -> ZoneResource:
	return ZoneFactory.new(rng).build_route("test_zone", "Test Route", 20, 15)
