# Publishing a release on GitHub.com

The repository workflow builds release files after a GitHub Release is published. No local build or command-line upload is required.

## First repository upload

1. Create an empty public repository named `spotlight-english` on GitHub. Do not add a README, license, or `.gitignore` on the creation page.
2. Upload this repository's source files to the `main` branch. Include `.github`, `.gitattributes`, and `.gitignore`; do not upload `.git`, `.build`, `dist`, or `.DS_Store`.
3. Open the repository's **Actions** tab and confirm that **Build and release** succeeds.

## Publish version 1.0.0

1. Open **Releases** and choose **Draft a new release**.
2. Choose **Create new tag**, enter `v1.0.0`, and target `main`.
3. Set the title to `Spotlight English 1.0.0`.
4. Generate release notes, review them, and select **Publish release**.
5. Wait for the **Build and release** workflow to finish. It attaches these files automatically:
   - `Spotlight-English-v1.0.0.dmg`
   - `Spotlight-English-v1.0.0.zip`
   - `SHA256SUMS.txt`

The release tag must match `CFBundleShortVersionString` from `Resources/Info.plist` with a `v` prefix.

## Gatekeeper and notarization

The default public build is ad-hoc signed. On first launch, users must Control-click the app, choose **Open**, and confirm. Accessibility permission is also required for the app's core function.

A normal double-click installation without a Gatekeeper warning requires an Apple Developer Program membership, a Developer ID Application certificate, hardened runtime signing, and Apple notarization.
