"""Encode third-order ambiX to the 8-channel TBE (FB360 "HHOA") format.

The conversion is a fixed linear matrix, published by Angelo Farina (2017),
"Ambisonics to TBE conversion", https://www.angelofarina.it/TBE-conversion-new.htm
The coefficients below are his *corrected* set.  His page documents that an
earlier FB360 Spatialiser build mixed ambiX channels Z and R into TBE(4),
producing wrong elevation; the corrected form takes Z alone, and `--check`
below reports which of the two a reference file was produced with.

Having this as a matrix rather than an application matters for reproducibility:
the FB360 Spatial Workstation is x86-only, GUI-driven and no longer maintained,
so any pipeline depending on it cannot be re-run from source.  This module
removes that dependency for the encoding half of the chain.

    python ambix_to_tbe.py in_ambix16.wav out_tbe8.wav
    python ambix_to_tbe.py --check reference_tbe.wav in_ambix16.wav

Input is ambiX in ACN/SN3D of third order or higher: because order reduction is
exactly channel truncation in that convention, a 64-channel seventh-order master
can be passed directly and no separate third-order file is needed.
"""

from __future__ import annotations

import argparse

import numpy as np
import soundfile as sf

# TBE channel (1-based) -> (ambiX ACN index, gain).  Farina (2017), corrected.
TBE_FROM_ACN = [
    (0, +0.488704),   # TBE 1  <- W
    (1, -0.488603),   # TBE 2  <- Y
    (3, +0.488603),   # TBE 3  <- X
    (2, +0.488603),   # TBE 4  <- Z   (R deliberately not mixed in)
    (8, -0.630783),   # TBE 5  <- U
    (4, -0.630783),   # TBE 6  <- V
    (5, -0.630783),   # TBE 7  <- T
    (7, +0.630783),   # TBE 8  <- S
]
N_AMBIX = 16


def matrix() -> np.ndarray:
    """The 16 x 8 encoding matrix, so that tbe = ambix @ matrix()."""
    m = np.zeros((N_AMBIX, len(TBE_FROM_ACN)))
    for out_ch, (acn, gain) in enumerate(TBE_FROM_ACN):
        m[acn, out_ch] = gain
    return m


def encode(ambix: np.ndarray) -> np.ndarray:
    """Encode ambiX to 8-channel TBE.

    Accepts any ambiX signal of third order or higher.  In ACN ordering with
    SN3D normalisation, reducing order is exactly truncation to the first
    (N+1)^2 channels, so a seventh-order master can be fed directly and no
    separate third-order intermediate file is required.
    """
    if ambix.shape[1] < N_AMBIX:
        raise ValueError(
            f"need at least {N_AMBIX} channels (third order); got {ambix.shape[1]}")
    return ambix[:, :N_AMBIX] @ matrix()


def check(reference_tbe: np.ndarray, ambix: np.ndarray) -> None:
    """Report which encoder produced a reference TBE file, and how well the
    published matrix reproduces it."""
    n = min(len(reference_tbe), len(ambix))
    a, b = ambix[:n, :N_AMBIX], reference_tbe[:n, :8]

    fitted, *_ = np.linalg.lstsq(a, b, rcond=None)
    resid = b - a @ fitted
    rms = np.sqrt((b ** 2).mean())
    print(f"  free least-squares fit residual : "
          f"{20*np.log10(max(np.sqrt((resid**2).mean()), 1e-30)/rms):+.1f} dB")

    z, r = fitted[2, 3], fitted[6, 3]
    print(f"  TBE(4) composition              : Z={z:+.4f}  R={r:+.4f}")
    print(f"  encoder variant                 : "
          f"{'corrected' if abs(r) < 0.05 else 'BUGGY (R mixed into TBE 4, wrong elevation)'}")

    pred = encode(ambix[:n])
    resid = b - pred
    print(f"  published-matrix residual       : "
          f"{20*np.log10(max(np.sqrt((resid**2).mean()), 1e-30)/rms):+.1f} dB")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", metavar="REFERENCE_TBE",
                    help="compare against a TBE file produced by the FB360 encoder")
    ap.add_argument("ambix", help="ambiX WAV, ACN/SN3D, third order or higher (>=16 ch)")
    ap.add_argument("output", nargs="?", help="8-channel TBE WAV to write")
    args = ap.parse_args()

    x, fs = sf.read(args.ambix, always_2d=True, dtype="float64")
    print(f"{args.ambix}: {x.shape[1]} ch, {len(x)/fs:.1f} s")

    if args.check:
        ref, fs_ref = sf.read(args.check, always_2d=True, dtype="float64")
        if fs_ref != fs:
            raise SystemExit("sample-rate mismatch between reference and ambiX")
        print(f"{args.check}: {ref.shape[1]} ch")
        check(ref, x)

    if args.output:
        sf.write(args.output, encode(x), fs, subtype="FLOAT")
        print(f"  -> {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
