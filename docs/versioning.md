# Versioning

## Overview

This document describes the versioning strategy for the Game On Flutter application, covering both the human-readable version name (from `pubspec.yaml`) and the Android version code (derived from CI/CD).

## Version Naming Scheme

### Version Name (`versionName`)

**Source**: `pubspec.yaml` → `version` field

```yaml
version: 0.1.1
```

Format: `MAJOR.MINOR.PATCH` following [Semantic Versioning](https://semver.org/).

| Component | When to Increment |
|-----------|-------------------|
| MAJOR     | Breaking changes, incompatible API changes |
| MINOR     | New features, backwards compatible |
| PATCH     | Bug fixes, backwards compatible |

**Example**: `0.1.1` → `0.1.2` (bug fix), `0.2.0` (new feature), `1.0.0` (stable release)

### Version Code (`versionCode`)

**Source**: GitHub Actions `github.run_number`

- Auto-increments on every workflow run
- Unique per build (required by Play Store)
- Integer only, must increase monotonically

```yaml
# In workflow (auto-populated)
versionCode: ${{ github.run_number }}
```

**Example**: Run #42 → `versionCode: 42`

## Releasing a New Version

### 1. Update Version Name

Edit `pubspec.yaml`:

```yaml
version: 0.2.0
```

Commit and push:

```bash
git add pubspec.yaml
git commit -m "chore: bump version to 0.2.0"
git push
```

### 2. Create Release Tag

Tag format: `v<MAJOR>.<MINOR>.<PATCH>`

```bash
git tag v0.2.0
git push origin v0.2.0
```

### 3. Workflow Trigger

The release workflow triggers on tag push matching `v*`:

```yaml
# .github/workflows/release.yml
on:
  push:
    tags:
      - 'v*'
```

This workflow:
- Builds Android App Bundle (`.aab`)
- Builds iOS Archive (`.xcarchive`)
- Publishes to Play Store / TestFlight (when configured)
- Creates GitHub Release with artifacts

## VersionCode Collision Warning

### The Problem

If you have **multiple workflows** that build Android artifacts (e.g., `release.yml`, `pr-check.yml`, `nightly.yml`), they **share the same `github.run_number` counter**.

| Workflow | Run # | versionCode |
|----------|-------|-------------|
| release  | 10    | 10          |
| pr-check | 11    | 11 ← **collision!** |
| nightly  | 12    | 12 ← **collision!** |

Play Store rejects uploads with duplicate `versionCode`.

### Solutions

**Option 1: Separate counters (recommended)**

Use a workflow-specific offset:

```yaml
# release.yml
versionCode: ${{ github.run_number }}

# pr-check.yml
versionCode: ${{ github.run_number + 100000 }}

# nightly.yml
versionCode: ${{ github.run_number + 200000 }}
```

**Option 2: Single release workflow**

Only build Android artifacts in one workflow. Other workflows skip Android build or build debug-only APKs with `versionCode: 0` (not uploadable).

**Option 3: Manual versionCode**

See [Manual Build](#manual-build-with-custom-versioncode) below.

### ⚠️ Critical Invariant

> **Never reuse a versionCode.** Once uploaded to Play Console (even internal testing), that integer is permanently consumed.

## Manual Build with Custom versionCode

### Local Build (Development)

```bash
# Debug APK (versionCode from pubspec.yaml not used)
flutter build apk --debug

# Release App Bundle with explicit versionCode
flutter build appbundle --release \
  --build-number=42
```

The `--build-number` flag sets `versionCode` directly.

### CI Override

For one-off builds with specific versionCode:

```yaml
# .github/workflows/manual-release.yml
on:
  workflow_dispatch:
    inputs:
      version_code:
        description: 'Custom versionCode (integer)'
        required: true
        type: string

jobs:
  build:
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter build appbundle --release --build-number=${{ inputs.version_code }}
```

Trigger via GitHub UI: **Actions → Manual Release → Run workflow**

## Troubleshooting "App Not Installed" Errors

### Common Causes

| Error | Cause | Fix |
|-------|-------|-----|
| `INSTALL_FAILED_VERSION_DOWNGRADE` | New build has lower versionCode than installed | Increment versionCode |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Signature mismatch (debug vs release) | Uninstall old version first |
| `INSTALL_PARSE_FAILED_NO_CERTIFICATES` | Unsigned or corrupt APK | Build with `--release` and proper signing |
| `INSTALL_FAILED_DUPLICATE_PERMISSION` | Duplicate `android:permission` in manifest | Check `AndroidManifest.xml` for duplicates |

### Debug vs Release Signatures

**Debug builds** are signed with debug keystore (`~/.android/debug.keystore`).

**Release builds** use your upload keystore.

> **You cannot update a debug install with a release build (or vice versa) without uninstalling first.**

```bash
# Check installed version
adb shell dumpsys package com.example.game_on | grep versionCode

# Uninstall before switching build types
adb uninstall com.example.game_on
```

### VersionCode Stuck at 1

If `versionCode` shows as `1` despite `github.run_number` being higher:

1. Check `android/app/build.gradle.kts` — ensure `versionCode` is **not hardcoded**
2. Verify workflow passes `--build-number` correctly
3. Confirm `flutter build appbundle` receives the argument

```kotlin
// android/app/build.gradle.kts - CORRECT (dynamic)
versionCode = flutterVersionCode.toInt()
versionName = flutterVersionName

// WRONG - hardcoded
versionCode = 1
```

### Play Store "Version code already used"

If upload fails with "Version code X has already been used":

1. Check Play Console → **Release → Testing → Internal testing** → **Release history**
2. Find the highest used versionCode
3. Next build must use `highest + 1` at minimum
4. Use manual workflow with `--build-number=<next_available>`

## Related Files

- `pubspec.yaml` — Version name source
- `.github/workflows/release.yml` — Release automation (when created)
- `android/app/build.gradle.kts` — Version code/name injection
- `android/app/src/main/AndroidManifest.xml` — Package name for adb commands

## Quick Reference

```bash
# Current version
grep '^version:' pubspec.yaml

# Build release with explicit versionCode
flutter build appbundle --release --build-number=123

# Check installed versionCode
adb shell dumpsys package com.example.game_on | grep versionCode

# Create release tag
git tag v0.2.0 && git push origin v0.2.0
```