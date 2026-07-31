# DAW sessions

The render chains behind the format variants in `data/`, provided so the routing,
panning and plugin parameters behind each variant are auditable rather than
implicit. These reference external media by relative path and do not embed
audio -- the underlying stimuli are not redistributed here, for the same
commercial-rights reason given in the top-level README.

## What is here

| file | purpose |
|---|---|
| `reaper/master_multiformat_render.RPP` | The canonical REAPER session covering all three content items (KWARTET, BigBand, DeusExMachina) and every format variant: 7OA/42pIKO/42pIKO-hemi masters, Dolby Atmos native 9.1.6, Auro-3D native 13.1, Sony 360RA native 5.1.4.4 plus its object layers, MagLS binaural renders (7OA/5OA/42pIKO, via the IEM Plug-in Suite), IAMF/Eclipsa, TBE, and the YouTube first-order ambisonic mix. |
| `reaper/presets/vst3-WalkMix Creator.ini` | Saved Sony 360 WalkMix Creator panner presets. Drop into `~/Library/Application Support/REAPER/presets/` to restore them in the plugin's preset browser. See the caveat below. |
| `reaper/presets/vst3-fiedler audio atmos beam.ini` | Saved Fiedler Audio Dolby Atmos Beam presets, same install location. Used here: `9.1.6` for the native Atmos bed, `42p IKO MODv2 01-16`, `17-32` and `33-42` for the full 42-point object chain, and `42p IKO hemisphere 01-16` and `17-26` for the 26-point hemispherical subset. The file also carries presets for layouts not used in this study (t-designs, spherical coverings), left in place rather than pruned. |
| `reaper/presets/vst3-fiedler audio atmos composer.ini` | Fiedler Audio Dolby Atmos Composer presets recording the render target for each Atmos chain: `master output - 9.1.6` for the native bed and `master output - 42pIKO` for the object chain. |
| `iem_layouts/IKO_42.json` | The 42-point geodesic icosahedron loudspeaker layout, loadable in both the IEM AllRADecoder and the IEM MultiEncoder. This is the intermediate representation the 42pIKO variants are built on. |
| `iem_layouts/IKO_42_hemisphere.json` | The hemispherical subset used for the Auro-3D chain: 26 loudspeakers at or above the horizon plus a single point at $-90^\circ$ standing in for the lower hemisphere, 27 entries in total. The 26 excludes that $-Z$ point, which is why the Auro-3D variant is described throughout as 26-point. |
| `protools/auro3d_render.ptx` | The Pro Tools session for the Auro-3D 13.1 native render, using the Auro-3D AAX chain (Panner, MixEngine, Bus, DownMixControl, AuxEngine, Headphone monitor). |
| `protools/presets/Auro-Panner/42pIKO_hemi26p_*.tfx` | 26 saved Auro-Panner presets, one per point of the hemispherical subset (see `IKO_42_hemisphere.json`), positioning each of the 26 objects. |
| `protools/presets/Auro-MixEngine/42pIKO_hemi26p_AuroMixingEngine.tfx` | Saved Auro-MixEngine preset for the same chain. |
| `protools/presets/Auro-Bus/42pIKO_hemi26p_AuroBus.tfx` | Saved Auro-Bus preset for the same chain. |

## Software versions

The results in the paper were produced with:

| tool | version |
|---|---|
| IEM Plug-in Suite | 1.15.0 |
| Fiedler Audio Dolby Atmos Composer/Beam | 1.6.1 |
| Sony 360 WalkMix Creator | 2.1.2 |
| Auro-3D Creative Tools Suite (AAX, Pro Tools) | 3.0.6 |
| Auro-3D Creative Tools Suite (AU/VST3, REAPER) | 1.1.2 |
| Auro-3D Encoder Service | 2.2.0 |
| IAMF Eclipsa plugins | 1.4.4 |
| Resonance Audio | 1.1.1 |
| REAPER | 7.78 (macOS arm64) |
| Pro Tools | 26.4.1.179 |

TBE / Meta Audio360 is documented separately in `pipeline/tbe/README.md`
(Audio360 AudioEngine 1.7.12), since it has its own build and licensing notes.

## Known limitation: single-master instance restrictions

Two of the plugin suites route audio internally between their own instances
and therefore tolerate only one active master instance at a time: 360 WalkMix
Creator and the Fiedler Audio Dolby Atmos Composer. This is not a license-seat
check but a constraint of their internal cross-instance routing. In practice
it meant saved presets did not reliably carry over when moving between
projects, and required manually toggling plugin instances off and on as a
workaround while working in the combined multi-format session, which hosts
several format chains side by side. The included WalkMix preset file captures
the panner state correctly, but loading it may still require working around
the same restriction if another project has the plugin open at the same time.

## What is deliberately excluded

Bounced/rendered audio, `Session File Backups/`, REAPER `AutoSaves/` and
`Backups/`, and the raw stimuli themselves are not included, for the same
reason the top-level README does not redistribute the binaural stimuli: they
derive from commercially released productions.
