# How to Implement New Mechanics

Feature requests will arrive as a description of the mechanic and its expected behavior, usually including specific example configs to create. Follow this process in order.

## Step 1 — Understand Before Building

- Read `DESIGN_BIBLE.md` & `CLAUDE.md` for the project and locate where this mechanic fits.
- Identify which existing systems are affected (EventBus signals, GameState properties, Manager autoloads, Resource schemas).
- **If anything is ambiguous or requires a design decision not covered by this file or DESIGN_BIBLE.md, stop and ask.** Do not make silent assumptions on design questions. Technical implementation choices (naming, structure) are fine to decide independently.
- Read any other `CLAUDE.md` files in the relevant directories for localized context.

## Step 2 — Design the Interface

Before writing any implementation code, define:

- What new signals, if any, need to be added to EventBus? (Remember: append only.)
- What is the `.tres` Resource schema for any new config types? What are the important knobs to turn and tune for this system? Are there any similar mechanics this new system can support easily?
- What enum value and match branch does this add to the relevant system?
- Where do the new files live in the project structure?
- Most systems should be designed and implemented with extensibility and easy replacement in mind. Do any existing interfaces need to be updated? Do we need a new interface?

## Step 3 — Implement

- Add to the appropriate enum and match statement.
- New branches must not change the behavior of existing branches.
- New data objects should implement de/serialize functions for easy saving/ loading
- New controller code should be easily configurable via `.tres` to describe which mechanics are active, and any settings associated with them

## Step 4 — Create Example Configs

- Create minimal `.tres` config files in the appropriate `content/` subdirectory that exercise the new mechanic.
- Configs must be loadable by `ConfigLoader` and usable by the relevant Manager with no additional code changes.
- The example configs provided in the feature request are the minimum. Additional configs that stress-test edge cases are welcome.

## Step 5 — Write Tests

Every mechanic ships with tests. Tests live alongside the system they test in a `tests/` subfolder of the relevant domain (e.g., `engine/battle/tests/`).

Required tests for every new mechanic:

- **Serialization tests:** Every new Resource class must have a test that instantiates it, populates it, saves it, reloads it, and asserts the values round-trip correctly.
- **Config loading tests:** A test that loads each example config through `ConfigLoader` and asserts it produces the expected Resource with correct values.
- **Controller unit tests:** Small, focused tests for the core logic of the mechanic (e.g., damage calculation, status effect application).

Most all unit tests should follow this three step design pattern:

- Step 1: set up inputs
- Step 2: set up and run code under test
- Step 3: Validate output

If there are mocks, it should follow the five step pattern:

- Step 1: set up mocks
- Step 2: set up inputs
- Step 3: Set up and run code under test
- Step 4: Validate output
- Step 5: Validate mocks

## Step 6 — Integration Scene

Provide a simple runnable Godot scene that exercises the mechanic end-to-end. The scene does not need a UI or human input — it can run automatically and emit results to the console via `print()`. The scene should demonstrate the mechanic working with the example configs from Step 4.

Place integration scenes in `engine/<domain>/tests/` alongside unit tests.

## Step 7 — Report Back

When complete, report:

- A brief summary of anything you were uncertain about or any notable design decision you made.
- Any updates that should be made to `CLAUDE.md` or other documentation files (living documents — flag if something has changed that should be captured).
- Do **not** summarize the implementation or echo back the code — the git diff covers that.
