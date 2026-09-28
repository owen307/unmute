# Unmute

Phone cues for a church booth. Each cue is an ordered list of steps that mute, unmute, or set the level of input channels on a **Behringer X32** or **Midas M32**. Press **GO**. There is no mixer UI and no account.

The Android app speaks OSC over UDP. Test mode logs every packet and sends nothing.

## Sunday setup

1. Put the phone on the **same network** as the console. Guest Wi-Fi that blocks clients from seeing each other will not work. Cellular will not work.
2. On the desk: **Setup → Network**. Write down the IPv4 address. OSC is always **UDP port 10023**. You do not pick a different port on the X32.
3. Install the debug APK (see below) and open **Unmute**.
4. Open **Setup**. Enter the console IP. Leave the port at `10023`. Leave **Local bind port** blank unless a firewall requires a fixed source port.
5. Leave **Test mode** on. Select a cue and press **GO**. Open **Log**. Lines marked **DRY** were not sent, and the faders must not move.
6. **Test connection** sends a single `/info` query even in test mode. A reply means the phone reached the desk. No reply can still be a one-way path; prove it with a live cue on a spare channel before the service.
7. Turn **Test mode** off and confirm the dialog. The banner turns red: **LIVE**. **GO** now changes the console.

The screen stays on while Unmute is open.

## The cue list

- Tap a row to make it **NEXT**. **GO** fires that cue, then loads the following one.
- **STOP** cancels a wait and any auto-follow chain. It does not mute the board.
- **Auto-follow** on a cue fires the next cue when this one finishes, including waits.
- Drag the handle to reorder. The pencil edits steps.

### ALL MUTE and RESTORE

**ALL MUTE** sends channel OFF to **input channels 1–32** immediately. It does not move the main fader, buses, or DCAs. Mute the main with a custom OSC step (`/main/st/mix/on`, int `0`) if you need that.

**RESTORE** replays the mute and level values **this phone actually sent** before the last ALL MUTE. It does not read the desk, and it does not unmute channels this phone never touched. Fire a cue while live once before you count on restore. Pressing ALL MUTE again does not forget that pre-panic snapshot.

Test mode does not update the restore snapshot, because nothing was sent.

## Example show

Loaded the first time the app opens. **Reload example cues** in Setup puts it back and keeps the IP. Channel names live on the phone only; they are not written to the console.

| Ch | Name |
| --- | --- |
| 1 | Pastor |
| 2 | Keys |
| 3 | Vocal 1 |
| 4 | Vocal 2 |
| 5 | Acoustic |
| 6 | Electric |
| 7 | Bass |
| 8 | Drums |

**Worship team on** — mute Pastor, unmute 2–8, set a music bed (Keys −6 dB, vocals −8, guitars −10, Bass −12, Drums −14).

**Pastor only** — unmute Pastor at 0 dB, mute 2–8.

**Band + vocal** — mute Pastor and Keys, unmute 3–8, vocals at −5 dB and the band a few dB under that.

Edit the names and levels to match the real patch. These numbers are a starting point, not a mix.

## Steps

| Step | What it sends |
| --- | --- |
| Unmute | `/ch/01/mix/on` with **int 1** (channel ON) |
| Mute | `/ch/01/mix/on` with **int 0** (channel OFF, muted) |
| Level | `/ch/01/mix/fader` with a **float 0–1** |
| Wait | No packet. Holds the cue for N milliseconds. |
| Custom OSC | Any address and int / float / string args. Use this for buses, DCAs, main, or another desk later. |

Channel numbers are 1–32, zero-padded (`/ch/01`, not `/ch/1`). A step can list channels as `1-4, 8`.

Mute is an **int**, matching the X32 OSC examples (`/ch/01/mix/on ,i 0`). It is not a float. `0` is OFF / muted. `1` is ON / unmuted.

### Fader float ↔ dB

The wire value is **not** decibels. The desk uses the piecewise curve documented by Patrick-Gilles Maillot (`float_to_db` / `db_to_float` in the unofficial X32/M32 OSC protocol):

| Console float | Desk |
| --- | --- |
| 0.0 | −∞ (formula endpoint −90 dB) |
| 0.0625 | −60 dB |
| 0.25 | −30 dB |
| 0.5 | −10 dB |
| 0.75 | 0 dB |
| 1.0 | +10 dB |

Between those points the segments are linear: −90…−60, −60…−30, −30…−10, −10…+10. The level step accepts either dB or a raw 0–1 float and shows both before you save. Values outside −90…+10 dB or 0…1 are clamped. `0.0` is what the console draws as −∞.

## Build the debug APK

Install [Flutter](https://docs.flutter.dev/install) (this repo is developed on stable **3.47.5**) and the Android SDK.

```bash
flutter pub get
flutter test
flutter build apk --debug
```

The APK is:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Copy it to the phone and install it. Debug builds are signed with the debug key, so Android may ask you to allow installs from that source. A release keystore is not required.

Run it on a connected phone with:

```bash
flutter run
```

`flutter test` covers OSC packet bytes, the fader curve, cue step order, dry-run (no UDP), ALL MUTE / RESTORE, auto-follow, and the cue list screen.

## GitHub Actions

[`.github/workflows/android-apk.yml`](.github/workflows/android-apk.yml) runs analyze, test, and `flutter build apk --debug` on push, pull request, and manual dispatch. Download the **unmute-debug-apk** artifact from the workflow run. It is the same debug APK as the command above.

## Where the show is stored

Cues, channel names, and the console IP are JSON in on-device preferences (`unmute.show.v1`). Nothing is uploaded. Clearing the app's storage loads the example show again. A file that will not parse is copied to `unmute.show.v1.bak` and replaced with the example.

## What this does not do

- It does not draw channel strips, meters, or EQ.
- It does not subscribe to the desk (`/xremote`) or chase fader moves made on the console.
- ALL MUTE does not touch main, buses, or DCAs.
- Browsers cannot send this UDP. Use the Android app on the booth phone.
