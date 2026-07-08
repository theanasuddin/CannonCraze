# Cannon Craze for Android

This folder is a complete, self-contained Android Studio project for the Android
edition of Cannon Craze. It is a faithful port of the desktop Processing sketch:
identical gameplay, physics, palette, and procedural sound, adapted for touch,
fullscreen phones and tablets, and the Play Store.

## What is different from the desktop build

| Area | Desktop | Android |
| --- | --- | --- |
| Window | Resizable window, 960 x 600 design canvas | Fullscreen immersive landscape, same design canvas scaled edge to edge |
| Renderer | Java2D with a resize-safe surface | P2D (OpenGL ES), GPU accelerated |
| Input | Mouse drag, hover cursor, ESC key | Single touch drag, system back gesture |
| Audio | javax.sound line pool | AudioTrack software mixer (`SoundEngine`) |
| Saves | `data/*.txt` files | `SharedPreferences` |
| Exit | ESC / EXIT button closes the window | Back gesture walks modal, then run, then menu; EXIT finishes the activity |

The fonts and the cannon glyph are not duplicated: the Gradle config reads them
straight from the repository's `data/` folder (`sourceSets` in
`app/build.gradle`), so both platforms share one set of assets.

## Requirements

- Android Studio (Koala or newer) with an Android SDK: platform 35 and
  build tools installed (Android Studio installs these on first sync)
- JDK 17 (bundled with Android Studio)
- A device or emulator running Android 5.0 (API 21) or newer

## Build and run

1. Open **this `android/` folder** (not the repository root) in Android Studio.
2. Let Gradle sync. The `processing-core.jar` runtime is vendored in
   `app/libs/`, so there is nothing else to fetch beyond standard AndroidX
   dependencies.
3. Press **Run** on a device or emulator.

Command line:

```bash
cd android
./gradlew assembleDebug          # debug APK: app/build/outputs/apk/debug/
./gradlew bundleRelease          # signed AAB for Play: app/build/outputs/bundle/release/
```

## Release signing

`bundleRelease` produces a signed bundle only when `android/keystore.properties`
exists. Copy `keystore.properties.example`, generate an upload keystore with the
`keytool` command shown inside it, and fill in the passwords. The file and any
`.jks` are gitignored; never commit signing secrets.

## Play Store deployment

Build the signed bundle with `./gradlew bundleRelease` (see Release signing
above). The store listing copy, content-rating answers, and required assets
are kept outside the public repository.

## Project layout

```
android/
|-- build.gradle                  # AGP 8.6, plugin management
|-- settings.gradle
|-- gradle.properties
|-- gradlew / gradlew.bat         # Gradle 8.9 wrapper
|-- keystore.properties.example   # template for release signing
`-- app/
    |-- build.gradle              # compileSdk 35, minSdk 21, shared assets
    |-- libs/processing-core.jar  # Processing for Android 4.6.1 runtime
    `-- src/main/
        |-- AndroidManifest.xml   # landscape, fullscreen, zero permissions
        |-- java/com/anasuddin/cannoncraze/
        |   |-- MainActivity.java # fragment host, immersive mode, back routing
        |   |-- Sketch.java       # the whole game, one PApplet
        |   `-- SoundEngine.java  # AudioTrack software mixer
        `-- res/                  # adaptive + legacy launcher icons, theme
```

## License

GPL-2.0, same as the rest of the repository. The vendored
`processing-core.jar` is the Processing for Android core library (LGPL),
distributed unmodified from the official Android Mode 4.6.1 release.
