class_name ActionResult
extends RefCounted
## Value object returned by ActionResolver.apply().
## Describes the full outcome of resolving a single Action.

var hit: bool = false
var damage: int = 0
var healed: int = 0
var stat_name: String = ""
var stat_delta: int = 0
var fainted: bool = false
