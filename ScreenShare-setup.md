# Laptop as a Second Mac Screen (ScreenShare)

The Mac (M1) supports only one external monitor. The old Dell XPS 13 laptop running Ubuntu now works as a second screen. It is low-lag and has no audio.

How it works:

```
Mac: BetterDisplay virtual screen ──> Sunshine (streams it)
        ──(Ethernet, HEVC 10 Mbit/s)──>
Laptop: Moonlight (shows it fullscreen)
```

## Daily use

- **Start or stop:** use the ScreenShare menu bar icon on the Mac, or press **⌃⌥⌘D**.
- **The laptop doesn't show the screen:** choose **Reconnect Laptop** in the menu.
- **Release the keyboard and mouse on the laptop:** press **Ctrl+Alt+Shift+Z**.
- **Show or hide the stream stats on the laptop:** press **Ctrl+Alt+Shift+S**.
- **When you're done:** shut down the laptop. It no longer sleeps when the lid is closed.

## Where things are

### Mac

| What | Where |
|---|---|
| Menu bar app (source code) | `~/Projects/ScreenShare` |
| Installed app | `/Applications/ScreenShare.app` |
| Sunshine config | `~/.config/sunshine/sunshine.conf` |
| Sunshine log | `~/.config/sunshine/sunshine.log` |
| Sunshine web page | https://localhost:47990 (user `sunshine`) |
| Sunshine password | Keychain item `ScreenShare-Sunshine` |
| BetterDisplay CLI | `/opt/homebrew/bin/betterdisplaycli` |

### Laptop (`ssh roach@192.168.1.120`)

| What | Where |
|---|---|
| Moonlight | `~/Apps/moonlight/squashfs-root` |
| Start/stop scripts | `~/.local/bin/screenshare-start`, `~/.local/bin/screenshare-stop` |
| Moonlight log | `/tmp/screenshare-moonlight.log` |
| Network (ARP) fix | `/etc/sysctl.d/99-arp-fix.conf` (made by `~/fix-arp.sh`) |
| Lid fix | `/etc/systemd/logind.conf.d/lid-ignore.conf` (made by `~/fix-lid.sh`) |

## What we installed and set up

### Mac

1. **BetterDisplay.** It makes a virtual screen called "LaptopScreen".
   - Resolutions: 1920x1080, 1600x900 and 1280x720, all at 60 Hz.
2. **Sunshine.** It streams that screen. It was installed from Homebrew (`lizardbyte/homebrew/sunshine`) and runs with `brew services`.
   - Settings: audio off, `fec_percentage = 40`, web page open on the LAN only.
   - It has Screen Recording permission.
   - It is paired with the laptop (client name "roth").
3. **ScreenShare menu bar app.** Written in Swift, it does every step for you.
   - **Start:** turns on the virtual screen → puts it next to the main screen → points Sunshine at it → restarts Sunshine → starts Moonlight on the laptop over SSH.
   - **Stop:** does the same steps in reverse.
   - **Options:** resolution, laptop position (left/right/top/bottom), start Moonlight on the laptop, pause AirDrop (kept off), launch at login.

### Laptop

1. **Moonlight 6.2.0** (AppImage).
   - It streams fullscreen with HEVC and hardware decoding.
   - V-Sync and frame pacing are on, at 10 Mbit/s and 60 fps.
2. **SSH key login** from the Mac, so no password is needed.
3. **ARP fix.** Without it, video came in over Wi-Fi instead of the cable.
4. **Lid fix.** The laptop stays awake when the lid is closed.

## Lag fixes we found

| Change | Result |
|---|---|
| Wi-Fi → USB Ethernet cable on the laptop | Ping went from about 47 ms to about 4 ms |
| ARP fix | Video really uses the cable now |
| HEVC instead of H.264 | Fewer dropped frames |
| Bitrate 20 → 10 Mbit/s | Fewer drops |
| V-Sync and frame pacing | No more judder |
| AirDrop off (optional) | Fewer Wi-Fi spikes on the Mac |

**Small stutter left:** the laptop's USB Ethernet adapter is only 100 Mbit/s. A gigabit USB-C adapter (RTL8153 chip) should fix most of it. Wiring the Mac too would help more.

## Notes

- The laptop's IP addresses are 192.168.1.120 (cable) and 192.168.1.231 (Wi-Fi).
  - If they change, edit `hosts` in `~/Projects/ScreenShare/Sources/Settings.swift` and rebuild.
  - A DHCP reservation in the router stops them from changing.
- **To rebuild the app:**
  ```
  cd ~/Projects/ScreenShare
  xcodebuild -project ScreenShare.xcodeproj -scheme ScreenShare -configuration Release -derivedDataPath build -quiet build
  cp -R build/Build/Products/Release/ScreenShare.app /Applications/
  ```
- **Raspberry Pi 3B:** it can work, but only with H.264 and 100 Mbit/s Ethernet, so it won't beat the laptop.
