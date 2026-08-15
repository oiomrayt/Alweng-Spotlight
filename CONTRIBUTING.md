# Contributing

Contributions are welcome.

1. Fork the repository and create a focused branch.
2. Build with `make build`.
3. Run the checks described below.
4. Open a pull request explaining the behavior change and the macOS/keyboard versions tested.

Before submitting:

```bash
swift build
plutil -lint Resources/Info.plist
zsh -n scripts/*.sh
```

Do not add network access, analytics, or third-party runtime dependencies without prior discussion. Preserve existing user HID mappings and keep Accessibility usage limited to the documented keyboard events.
