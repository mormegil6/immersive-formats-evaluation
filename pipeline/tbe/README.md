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
`include/` and `libAudio360.dylib` are not in it. Meta no longer distributes the
suite, so obtaining the SDK now means an existing local installation or a
third-party copy, and whether a given copy may be used is a licensing question
for whoever obtains it. We do not redistribute it here and do not point at any
particular source.

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

## Note on latency

The Audio360 renderer introduces a transport delay of roughly 74 ms. This is a
property of the renderer, not a quality degradation, and it is removed by the
alignment stage in `pipeline/src/prepare_stimuli.py` before scoring. Leaving it
uncompensated changes BINAQUAL's localisation similarity substantially -- see the
paper, and the control arm in `data/metrics_long_noalign.csv`.
