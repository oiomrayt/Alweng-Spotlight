# Architecture

Spotlight English is a single-process AppKit menu-bar application.

## Event flow

1. At launch, the app reads the current `UserKeyMapping` value with `/usr/bin/hidutil`.
2. It preserves all mappings except the Apple Spotlight-key entry and maps that entry to F13.
3. AppKit observes the otherwise-unused F13 event.
4. Text Input Source Services selects the configured English input source.
5. A 3×3 transparent temporary key window activates for at least 150 ms. This avoids a macOS 26 race where a background `TISSelectInputSource` call can report success before the source is applied.
6. Core Graphics posts Command-Space to open the system Spotlight UI.
7. At normal termination, the app restores the previous Spotlight-key mapping while preserving unrelated mappings.

## Trust boundaries

- No network APIs are used.
- No data is stored except the selected input-source ID in `UserDefaults`.
- `hidutil` changes are session-scoped and normally reset after logout or reboot.
- Accessibility is required for the global key monitor and synthetic Command-Space event.
