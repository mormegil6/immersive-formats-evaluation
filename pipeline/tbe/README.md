# TBE (8-channel hybrid Ambisonic) rendering

Tools for encoding ambiX to the 8-channel TBE/Audio360 layout and rendering it
to binaural offline, without a DAW.

## What is here

| file | purpose |
|---|---|
| `ambix_to_tbe.py` | ambiX (ACN/SN3D) → 8-channel TBE, using the corrected Farina (2017) matrix. Accepts any input of 16 channels or more and truncates, so a 7OA master can be fed directly. |
| `tbe_render.cpp` | Offline binaural renderer built on the Audio360 engine. Uses `AudioDeviceType::DISABLED` with a `SpatDecoderQueue` and pulls frames through `getAudioMix()`, so it runs headless with no audio device. |
| `render_tbe.py` | Driver: encodes, renders and writes the binaural result. |

## The SDK is not included

`tbe_render.cpp` links against Meta's **Audio360 SDK**, which is proprietary and
is not redistributable. The headers (`include/`), the shared library (`lib/`) and
the compiled `tbe_render` binary are therefore excluded from this repository.

The FB360 Spatial Workstation is discontinued and the project has been archived
at <https://github.com/facebookarchive/facebook-360-spatial-workstation>. That
archive carries the documentation and helper scripts but **not** the SDK itself:
`include/` and `libAudio360.dylib` are not in it, and neither do the installer
packages: the Mac bundle holds the `.pkg`, examples and the guide, and the
Windows one holds the VST plugins plus its ffmpeg/GPAC/Python dependencies.
The SDK was always a separate developer download. Whether a given copy may be
used is a licensing question for whoever obtains it; we do not redistribute it
here.

**A working installer mirror exists**, maintained by the late Prof. Angelo
Farina: <https://angelofarina.it/Public/FB360/>, with separate Mac and Windows
builds and the FFmpeg/GPAC/Python dependencies the installer needs. It is a
personal academic page with no institutional backing and no listed maintainer
since his passing, so we archived it in full on the Wayback Machine rather than
link it and hope: every installer, dependency and readme on that page --
including one that was previously uncaptured despite the page itself having
snapshots going back years -- is now saved at full size, verified byte-for-byte
against the live files:

- <https://web.archive.org/web/20260511153757/https://angelofarina.it/Public/FB360/> (top-level index)
- <https://web.archive.org/web/20260729102037/https://angelofarina.it/Public/FB360/Mac-new-2023/> (Intel + Apple Silicon build, 493 MB)
- <https://web.archive.org/web/20260729102634/https://angelofarina.it/Public/FB360/Win/> (Windows VST, 129 MB)
- <https://web.archive.org/web/20260729103004/https://angelofarina.it/Public/FB360/Mac-old/> (Intel/Big Sur build, plus a `mac-M1-support.zip` we had not seen referenced elsewhere)

**The SDK itself is hosted separately on the same site**, in a different
directory that the FB360 index above does not link, which is why it took a
while to find. It was not captured by the Wayback Machine at all until we
requested it on 2026-08-15; these are the first snapshots that exist:

- <https://web.archive.org/web/20260815073925/https://www.angelofarina.it/Public/Facebook-Spatial-Workstation/Download/SDK/> (index)
- <https://web.archive.org/web/20260815073938/https://www.angelofarina.it/Public/Facebook-Spatial-Workstation/Download/SDK/Audio360_SDK_1.7.12-cd52f5f44271.zip> (1.7.12, 388 MB, the version used here)
- <https://web.archive.org/web/20260815073950/https://www.angelofarina.it/Public/Facebook-Spatial-Workstation/Download/SDK/Audio360_SDK_1.3.0.zip> (1.3.0)

Unzipping gives `Audio360/include/` and `Audio360/macOS/libAudio360.dylib`,
which is what `tbe_render.cpp` builds against.

If the source page goes offline, everything needed to install FB360 and to
build against its SDK is still retrievable from the links above.

**Version used here.** The results in the paper were produced against Audio360
(TBE AudioEngine) **1.7.12**, x86_64. If you have a copy, you can check yours
with:

```bash
grep -h TBE_AUDIOENGINE_VERSION include/TBE_AudioEngine.h
lipo -archs lib/libAudio360.dylib
```

Recording this matters more than it normally would: the suite is archived, no
canonical download remains, and copies in circulation may differ. A different
engine version may not reproduce the numbers here exactly.

To build, once you have it:

1. Place the Audio360 headers in `include/` and `libAudio360.dylib` in `lib/`.
2. Build for x86_64 -- the shipped library is Intel-only, so on Apple Silicon the
   binary runs under Rosetta:

   ```bash
   clang++ -std=c++14 -arch x86_64 -O2 \
       -I include tbe_render.cpp -L lib -lAudio360 \
       -Wl,-rpath,@loader_path/lib -o tbe_render
   ```

Everything else in this repository runs without the SDK. Only the TBE variant
depends on it, and the scored results for that variant are already included in
`data/metrics_long.csv`, so the analysis reproduces without rebuilding it.

## Using it

**Platform.** The encoder is portable Python. The renderer is not: it links a
macOS `libAudio360.dylib`, and the shipped library is Intel-only, so on Apple
Silicon the binary must be built for x86_64 and invoked under Rosetta. Meta also
shipped Windows and Linux builds of the SDK; the renderer has not been built or
tested against those here, and `tbe_render.cpp` would need its link flags
adjusted.

**Dependencies.** The encoder needs only `numpy` and `soundfile`:

```bash
python3 -m venv .venv && .venv/bin/pip install numpy soundfile
```

The pinned `pipeline/requirements.txt` at the repository root is for the full
scoring pipeline and is not needed for TBE work.

**Encode ambiX to 8-channel TBE** (no SDK required, any platform):

```bash
.venv/bin/python ambix_to_tbe.py master_ambix.wav out_tbe.wav
```

Input is ambiX (ACN/SN3D), third order or higher; inputs with more than 16
channels are truncated, so a 7OA master can be fed in directly. To check the
result against a TBE file produced by the FB360 encoder:

```bash
.venv/bin/python ambix_to_tbe.py master_ambix.wav --check reference_tbe.wav
```

**Render TBE to binaural** (needs the SDK and a built `tbe_render`):

```bash
.venv/bin/python render_tbe.py out_tbe.wav binaural.wav
.venv/bin/python render_tbe.py out_tbe.wav binaural.wav --verify reference_binaural.wav
```

`render_tbe.py` accepts 8-channel (TBE_8) or 10-channel (TBE_8_2) input and
writes a stereo WAV. `--verify` compares against a reference decode and is the
quickest way to confirm the chain is working rather than merely running: a
correct decode is a genuine binaural signal, not a passthrough or a silent file.

**If the build succeeds but the renderer produces silence**, the usual cause is
an architecture mismatch between the binary and the dylib. Check with
`file tbe_render` and `lipo -archs lib/libAudio360.dylib`; both must be x86_64.

## Note on latency

The Audio360 renderer introduces a transport delay of roughly 74 ms. This is a
property of the renderer, not a quality degradation, and it is removed by the
alignment stage in `pipeline/src/prepare_stimuli.py` before scoring. Leaving it
uncompensated changes BINAQUAL's localisation similarity substantially -- see the
paper, and the control arm in `data/metrics_long_noalign.csv`.
