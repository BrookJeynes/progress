# Changelog

## v2.0.0 (2026-04-22)
- chore: Update project to Zig v0.16.0
- fix: `extra_front_chars` was incorrectly handling padding. Now accounts for custom bars.
- refactor: Update PredefinedSymbols namespace from enum to struct
- refactor: `colour` and `bg_colour` api has been updated. These are now set in the config and updated via `update[Colour|BgColour]`.
- refactor: `setShowBg([true|false])` is now used to update background visibility.
- fix: Unchecked usize subtraction.
- fix: Double `clear()` in Spinner when `completion_character` and `clear_on_finish` are both set.
- fix: Render race condition and redundant width calculation.

## v1.2.1 (2025-03-26)
- chore: Update project to Zig v0.14.0

## v1.2.0 (2025-01-09)
- feat: Added the ability to colour progress bar.
- feat: Added option to show background character for progress bar.
- chore: Updated examples to showcase new colour options.
- refactor: Renamed escape_codes.zig to ansi-term.zig and added correct 
  copyright attribution.

## v1.1.0 (2024-10-28)
- Progress bar now supports u21 ascii characters.
- Updated bar/complex.zig example to showcase this.
- Added new `completionCharacter` config. This character, if defined,
  gets printed instead of the spinner symbol on `Spinner.finish()`.
- `updateDescriptionNewline` allows you to now retain the previous
  spinner symbol / description on the previous line and start a new task
  on the next. This goes hand in hand with the new `completionCharacter`
  config.
- Updated casing from `update_description()` to `updateDescription()`.
- Update doc strings to make render functionality for spinners more obvious.

## v1.0.0 (2024-07-18)
- Added spinners! Check out `examples/spinner` for api usage or check
  the docs `zig build docs`.
- Renamed `progress.zig` to `bar.zig`. This change came from the need
  of having two progress variants, `bar.zig -> Bar` and `spinner.zig ->
  Spinner`.
- Added `Bar.isCurrent()` as a thread safe way of checking the current
  progress of a progress bar.
- Updated and split up examples, `examples/bar` and `examples/spinner`.
- Updated `build.zig` to allow running both spinner and bar examples,
  e.g. `zig build run-bar-complex` vs `zig build run-spinner-complex`.
- Updated `README` with new examples.
- Updated docstrings in `bar.zig`
- `Bar.finish()` can now error. This was always the intent but I missed
  a `!`... whoops. This is now fixed.
