# yabasanshiro-pirry — Sega Saturn emulator for R36S / RK3326 handhelds

![yabasanshiro-pirry — Sega Saturn emulator for R36S / RK3326 handhelds](banner.jpg)

**Faster Sega Saturn emulation on R36S-class retro handhelds** (RK3326:
R36S, R35S, K36, RG351 family and other clones running ArkOS). This is a
build of [Yaba Sanshiro](https://github.com/devmiyax/yabause) 1.20.37 by
devMiyax, **optimized for performance** on the Mali-G31 GPU and
Cortex-A35 CPU of these devices: depending on the game it runs faster
than the stock build — roughly **10–15 FPS more** in the titles tested.
Demanding 3D games (e.g. Sega Rally, Exhumed) that used to run in the
low-to-mid 20s now reach the **mid-30s to 40**. It stays below a locked
60 on heavy titles — this is not full-speed Saturn, it is as fast as this
hardware gets.

## The optimizations in this build

Days of profiling directly on the device (thread sampling, GL call
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
- **Shader-bind diet** — a program cache skips redundant `glUseProgram`
  calls. On these devices the Mali blob driver's per-call CPU overhead is
  a real bottleneck, not GPU horsepower.
- **Hidden CPU eaters removed** — the emulator core polled the system
  clock on every VRAM write and every memory-profile tick; throttled,
  which alone recovered measurable emulation speed.
- **Crash fixes** — X-Men: Children of the Atom crashed the stock build
  on a framebuffer readback without a GL context; fixed, and the game
  boots with its own per-game timing mode.
- **Fixed config submenus** — menu popups no longer open off-screen at
  640×480.

## Measured FPS (on the test device — K36/R36S clone, dArkOS)

Full-speed Saturn is 50/60 FPS; none of these hit a locked 60 — that is the
hardware ceiling of the RK3326, not a bug. These are what the on-screen
counter shows during play (they vary by scene):

| Game | FPS |
|---|---|
| Exhumed | ~40, up to ~50 in simple areas |
| Sega Rally (racing) | ~32–37 |
| Astal | ~33 |
| Thunder Force V | ~32 |
| Virtua Fighter 2 | ~25–27 (CPU-heavy) |
| Sonic R | ~20 (one of the heaviest) |

## This beta — SCSP sound-core change & settings

This build is about **performance / FPS** (see the optimizations above).
**Sound is still a work in progress and not fixed.** The one sound change
in this beta: it ships with the alternative SCSP sound-chip core enabled by
default (`classic scsp: false`), which removes the high-pitched squeal the
stock core produced on some games' sound effects. The sound still lags
behind and crackles on demanding games running below full speed — improving
that is the next task.

**Sound settings** (in `~/.yabasanshiro/default.config`, edit only while
the emulator is closed — it rewrites the file on exit):

- `"classic scsp": false` — the alternative SCSP core (recommended).
  `true` is the old core with the squeal.
- `"sound sync mode": "realtime"` — default. `"cpu"` can clean up the
  CD-audio (Redbook) track of some games, e.g. **Sega Rally**, at little or
  no FPS cost — but it helps some games and not others, so try it per game.

**On-screen FPS counter** — shown by default. Toggle it off from the
in-game menu (temporary), or set it permanently in the config.

**Aspect ratio / borders** — set per game from the in-game menu; the choice
is saved as `<game name>.config`. A freshly added game shows black borders
until you set it once.

**Frame skip** (`"frame skip": true`) — keep it on. It is what keeps 3D
games playable; with it off, demanding titles run in slow motion.

**Vertical / TATE shmups** (`"Rotate screen"`, `"Rotate screen resolution"`)
— rotate the display for games meant to be played with the screen turned.

Other keys (`"cpu sync per line"`, `"Use compute shader"`, `"jit block
link"`, `"async vdp1 readback"`, `"Resolution"`) are advanced timing/render
options — leave them at the defaults shipped in `default.config`.

Config files live in `~/.yabasanshiro/`: `default.config` for the global
defaults and `<game name>.config` per game.

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

GPL v2 or later, same as upstream Yabause / Yaba Sanshiro. The
corresponding source for this build is available on request.

## Keywords

Sega Saturn emulator, R36S, R36S emulator, RK3326, ArkOS, K36, retro
handheld, Yaba Sanshiro, Yabause, Sega Rally 30 FPS, Saturn emulation
performance, Mali-G31.
