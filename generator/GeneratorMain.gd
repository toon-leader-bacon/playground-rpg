extends SceneTree
## CLI entrypoint for the content generator.
##
## Run this script headlessly to generate .tres resource files from named recipes.
## See generator/README.md for full usage documentation and examples.
##
## Quick start:
##   godot --headless -s res://generator/GeneratorMain.gd -- --list-recipes
##   godot --headless -s res://generator/GeneratorMain.gd -- --recipe stat_pokemon_tank

const _Registry = preload("res://generator/GeneratorRegistry.gd")

const _DEFAULT_OUT_DIR: String = "res://content/generated/"
const _DEFAULT_COUNT: int = 1


func _initialize() -> void:
	var raw_args: Array = OS.get_cmdline_user_args()
	var args: Array[String] = []
	for a: Variant in raw_args:
		args.append(str(a))

	if args.is_empty() or "--help" in args or "-h" in args:
		_print_help()
		quit(0)
		return

	if "--list-recipes" in args:
		_list_recipes()
		quit(0)
		return

	if "--clean" in args:
		_clean(_DEFAULT_OUT_DIR)
		quit(0)
		return

	var recipe_name: String = _get_arg(args, "--recipe", "")
	var out_dir: String = _get_arg(args, "--out-dir", _DEFAULT_OUT_DIR)
	var out_prefix: String = _get_arg(args, "--out-prefix", "")
	var count: int = int(_get_arg(args, "--count", str(_DEFAULT_COUNT)))
	var seed_str: String = _get_arg(args, "--seed", "")

	if recipe_name.is_empty():
		_error("--recipe is required. Use --list-recipes to see available recipes.")
		return

	var recipes: Dictionary = _Registry.get_all()
	if not recipes.has(recipe_name):
		_error("Unknown recipe '%s'. Use --list-recipes to see available recipes." % recipe_name)
		return

	if count <= 0:
		_error("--count must be a positive integer.")
		return

	var rng := RandomNumberGenerator.new()
	if seed_str.is_empty():
		rng.seed = int(Time.get_unix_time_from_system() * 1000.0)
		print("Seed: %d (time-based)" % rng.seed)
	else:
		rng.seed = int(seed_str)
		print("Seed: %d (provided)" % rng.seed)

	if not _ensure_dir(out_dir):
		return

	var recipe_entry: Dictionary = recipes[recipe_name]
	var recipe_func: Callable = recipe_entry["func"]

	print("Recipe:  %s" % recipe_name)
	print("Count:   %d" % count)
	print("Out dir: %s" % out_dir)
	print("")

	for i: int in range(count):
		var resource: Resource = recipe_func.call(rng)
		var filename: String = _build_filename(out_prefix, recipe_name, i, count)
		var path: String = out_dir.path_join(filename)
		var err: Error = ResourceSaver.save(resource, path)
		if err != OK:
			_error("Failed to save '%s' (error code %d)" % [path, err])
			return
		print("  Saved: %s" % path)

	print("")
	print("Done.")
	quit(0)


## Two-stage trash for the generated directory.
## First call:  moves all files in generated/ → generated/old/
## Second call: deletes generated/old/, then moves current files to old/ again.
## Running --clean twice permanently discards the first batch.
func _clean(generated_dir: String) -> void:
	var old_dir: String = generated_dir.path_join("old")

	# Step 1: delete everything currently in generated/old/
	var old_abs: String = ProjectSettings.globalize_path(old_dir)
	if DirAccess.dir_exists_absolute(old_abs):
		var old_access: DirAccess = DirAccess.open(old_dir)
		if old_access == null:
			_error("Could not open '%s' for deletion." % old_dir)
			return
		var deleted: int = 0
		for filename: String in old_access.get_files():
			var err: Error = old_access.remove(filename)
			if err != OK:
				_error("Could not delete '%s' (error code %d)" % [old_dir.path_join(filename), err])
				return
			deleted += 1
		print("Deleted %d file(s) from %s" % [deleted, old_dir])
	else:
		print("No old/ directory found — nothing to delete.")

	# Step 2: move all files from generated/ into generated/old/
	if not _ensure_dir(old_dir):
		return

	var gen_access: DirAccess = DirAccess.open(generated_dir)
	if gen_access == null:
		print("Generated directory does not exist yet — nothing to archive.")
		print("Done.")
		return

	var moved: int = 0
	for filename: String in gen_access.get_files():
		var src: String = generated_dir.path_join(filename)
		var dst: String = old_dir.path_join(filename)
		var err: Error = gen_access.rename(src, dst)
		if err != OK:
			_error("Could not move '%s' to old/ (error code %d)" % [filename, err])
			return
		moved += 1

	print("Archived %d file(s) to %s" % [moved, old_dir])
	print("")
	print("Done.")


func _build_filename(prefix: String, recipe: String, index: int, total: int) -> String:
	var base: String = prefix if not prefix.is_empty() else recipe
	if total == 1:
		return base + ".tres"
	return "%s_%d.tres" % [base, index]


func _ensure_dir(path: String) -> bool:
	var abs_path: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var err: Error = DirAccess.make_dir_recursive_absolute(abs_path)
	if err != OK and err != ERR_ALREADY_EXISTS:
		_error("Could not create output directory '%s' (error code %d)" % [path, err])
		return false
	return true


func _get_arg(args: Array[String], flag: String, default_val: String) -> String:
	var idx: int = args.find(flag)
	if idx == -1 or idx + 1 >= args.size():
		return default_val
	return args[idx + 1]


func _list_recipes() -> void:
	var recipes: Dictionary = _Registry.get_all()
	var names: Array = recipes.keys()
	names.sort()
	print("Available recipes (%d total):" % names.size())
	print("")
	for name: Variant in names:
		var entry: Dictionary = recipes[name]
		var desc: String = entry.get("description", "")
		if desc.is_empty():
			print("  %s" % name)
		else:
			print("  %-40s %s" % [name, desc])
	print("")


func _print_help() -> void:
	print("""
Content Generator — Playground RPG
===================================
Run this script headlessly to generate .tres resource files from named recipes.

Usage:
  godot --headless -s res://generator/GeneratorMain.gd -- [options]

Options:
  --recipe <name>       Recipe to run (required). See --list-recipes.
  --count <n>           Number of resources to generate (default: 1).
  --out-dir <path>      Output directory as a res:// path (default: res://content/generated/).
  --out-prefix <name>   Filename prefix. Defaults to the recipe name.
  --seed <n>            Integer seed for reproducible output. Defaults to timestamp.
  --list-recipes        List all available recipes with descriptions, then exit.
  --clean               Archive generated/ to generated/old/, deleting any previous old/ first.
  --help, -h            Show this message.

Examples:
  # List all available recipes
  godot --headless -s res://generator/GeneratorMain.gd -- --list-recipes

  # Generate one stat block using the pokemon_tank recipe
  godot --headless -s res://generator/GeneratorMain.gd -- --recipe stat_pokemon_tank

  # Generate 5 stat blocks into content/stats/ with a filename prefix
  godot --headless -s res://generator/GeneratorMain.gd -- \\
      --recipe stat_pokemon_balanced --count 5 \\
      --out-dir res://content/stats/ --out-prefix balanced_test

  # Reproduce a previous result exactly with a fixed seed
  godot --headless -s res://generator/GeneratorMain.gd -- --recipe stat_ff_tank --seed 12345

See generator/README.md for more details.
""")


func _error(message: String) -> void:
	printerr("ERROR: " + message)
	quit(1)
