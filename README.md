# yabasanshiro-pirry — Sega Saturn emulator for R36S / RK3326 handhelds

![yabasanshiro-pirry — Sega Saturn emulator for R36S / RK3326 handhelds](banner.jpg)

**Faster Sega Saturn emulation on R36S-class retro handhelds** (RK3326:
R36S, R35S, K36, RG351 family and other clones running ArkOS). This is a
build of [Yaba Sanshiro](https://github.com/devmiyax/yabause) 1.20.37 by
devMiyax, **optimized for performance** on the Mali-G31 GPU and
Cortex-A35 CPU of these devices: depending on the game, expect
**10–20 FPS more** than before — in demanding 3D titles that used to
crawl at ~20 FPS that is close to **twice the frame rate**, now running
in the mid-30s to 40.

## The optimizations in this build

Weeks of profiling directly on the device (thread sampling, GL call
counting, per-subsystem timing) went into finding where the frames
actually die. The result:

- **Frame pipelining** — in stock 1.20.37 the emulation thread stops and
  waits for the render thread at every VBlank, twice per frame. Here the
  two run overlapped with a one-frame pipeline; the CPU emulates the next
  frame while the GPU still draws the previous one.
- **Scissor-based sprite clipping** — the stock renderer rebuilds a
  stencil mask for *every* sprite-clip state change: a full stencil
  buffer clear, an invisible mask quad, plus two shader switches. 3D
  games toggle clip state per sprite, hundreds of times per frame. This
  build replaces all of it with a single `glScissor` rectangle:
  **+8–9 FPS in Sega Rally from this change alone.**
- **Shader-bind diet** — a program cache swallows redundant
  `glUseProgram` calls (up to −85% binds in UMK3). On these devices the
  Mali blob driver's per-call CPU overhead is the real bottleneck, not
  GPU horsepower.
- **Profile-guided optimization (PGO)** — the binary is compiled against
  execution profiles recorded from real gameplay on the actual device,
  so the compiler optimizes the code paths Saturn games really hit.
- **Sound pipeline tuning** — sound-chip synchronization reduced to once
  per frame and the audio buffer operating point raised; less crackle,
  and the CPU time saved goes into frames.
- **Hidden CPU eaters removed** — the emulator core polled the system
  clock on every VRAM write and every memory-profile tick; throttled,
  which alone recovered measurable emulation speed.
- **Crash fixes** — X-Men: Children of the Atom crashed the stock build
  on a framebuffer readback without a GL context; fixed, and the game
  boots with its own per-game timing mode.
- **Fixed config submenus** — menu popups no longer open off-screen at
  640×480.

## Installation

Works on **Debian-based custom firmwares** for RK3326 handhelds — ArkOS
and its clone-device forks like **dArkOS** (tested on a K36/R36S clone
running dArkOS). Other Debian/Ubuntu-based CFWs should work as long as
libsdl2, libssl3 and zlib are available.

1. Download the latest release archive from the
   [Releases](../../releases) page.
2. Unpack it on the device (e.g. to `/opt/yabasanshiro`).
3. Launch a game:
   `LD_LIBRARY_PATH=./mali ./yabasanshiro -i "/roms/saturn/<game>.chd"`

Saturn BIOS (`bios.bin`) goes into `~/.yabasanshiro/`. Per-game settings
are stored as `<game name>.config` next to the default config.

## License

GPL v2 or later, same as upstream Yabause / Yaba Sanshiro. The full
source code will be published alongside the binary releases.

## Keywords

Sega Saturn emulator, R36S, R36S emulator, RK3326, ArkOS, K36, retro
handheld, Yaba Sanshiro, Yabause, Sega Rally 30 FPS, Saturn emulation
performance, Mali-G31.
