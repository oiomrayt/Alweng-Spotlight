# Spotlight English

Spotlight English is a tiny native macOS menu-bar utility that makes the physical Spotlight key open Spotlight with an English input source selected.

It is useful on multilingual Macs where Spotlight otherwise opens using the input source from the previously focused app.

[Русская версия](README.ru.md)

## What it does

When you press the physical Spotlight key (the magnifying-glass key, usually F4), the app:

1. remaps the Apple Spotlight key to an unused F13 key with Apple's built-in `hidutil`;
2. selects the configured English input source;
3. waits until macOS has actually applied the change;
4. opens the system Spotlight window.

The app has no network access, analytics, accounts, third-party runtime dependencies, or background services beyond the app itself and macOS `launchd` when installed with the helper script.

## Requirements

- macOS 13 or later;
- an Apple keyboard with the physical Spotlight key (`0x0C00000221`);
- an enabled English input source;
- Accessibility permission, required to observe F13 and send Command-Space.

The macOS 26 input-source timing workaround has been tested with `RussianWin → U.S.`.

## Install a release

1. Download `Spotlight-English-v1.0.0.dmg` from Releases.
2. Open the image and drag `Spotlight English.app` to Applications.
3. On first launch, Control-click the app, choose **Open**, and confirm.
4. Allow it in **System Settings → Privacy & Security → Accessibility**.
5. Add it to **System Settings → General → Login Items**, or use the repository install script.

The menu-bar magnifying-glass icon lets you choose the target English input source, run a test, or quit the app.

## Build from source

Xcode Command Line Tools or Xcode with Swift 5.9+ are required.

```bash
git clone https://github.com/oiomrayt/spotlight-english.git
cd spotlight-english
make build
```

The app will be created at `dist/Spotlight English.app`.

To build a universal Apple Silicon + Intel binary:

```bash
make universal
```

To build the universal app, DMG, ZIP, and checksums:

```bash
make release
```

To build and install the app in `/Applications` with a per-user `launchd` login agent:

```bash
make install
```

To remove both the app and login agent:

```bash
make uninstall
```

## Privacy and security

- All processing happens locally.
- The app does not contain networking code.
- Accessibility is used only for the global F13 event and Command-Space event.
- Existing `hidutil` mappings are preserved. The app temporarily replaces only the Spotlight-key mapping and restores it when the app exits normally.
- An abnormal termination may leave the F4→F13 mapping active until the next login or reboot.

See [SECURITY.md](SECURITY.md) for reporting security issues.

## Known limitations

- It only handles Apple's physical Spotlight-key HID usage, not arbitrary third-party keyboards.
- Spotlight must still be assigned to Command-Space in macOS Keyboard Shortcuts.
- The release workflow creates an ad-hoc-signed artifact by default. Public distribution without Gatekeeper warnings requires an Apple Developer ID certificate and notarization.

See [docs/RELEASING.md](docs/RELEASING.md) for publishing through the GitHub website.

## License

MIT. See [LICENSE](LICENSE).
