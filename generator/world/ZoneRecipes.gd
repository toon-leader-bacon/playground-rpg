class_name ZoneRecipes
extends RefCounted
## Curated zone generation recipes. Each function captures one specific,
## repeatable design configuration.
##
## All functions accept an rng parameter (even if unused) to satisfy the
## generator registry Callable signature: (rng: RandomNumberGenerator) -> Resource.


static func test_route(rng: RandomNumberGenerator) -> ZoneResource:
	return ZoneFactory.new(rng).build_simple_route("test_zone", "Test Route", 20, 15)
