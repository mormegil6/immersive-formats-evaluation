"""Coherence-weighted phase-slope test for a residual constant delay.

Integer alignment leaves, per variant, a fractional residual read from the
parabolic peak of the averaged cross-correlation (``subsample_residual`` in
the conditioning manifest). This script asks whether that residual behaves
like a delay at all: if a constant delay remained, the cross-spectrum phase
between reference and test would rise linearly with frequency,
phase = 2*pi*f*delay/fs, and the magnitude-squared coherence would be close
to one across the band.

Method: cross-spectrum, auto-spectra and coherence are accumulated over 15
Hann-windowed analysis windows of 10 s, spanning the excerpt, on a mono
downmix. The unwrapped cross-spectrum phase between fmin and fmax is fitted
by weighted least squares against x = 2*pi*f/fs, weight = coherence
squared; the slope is the delay in samples, and the intercept and the
weighted RMS residual are reported beside it. The fit carries an intercept
because np.unwrap fixes the phase progression but not its absolute value:
the principal value at fmin is known only modulo 2*pi, so a fit forced
through the origin is biased by 2*pi*k once the delay exceeds fs/(2*fmin)
samples.

The intercept and the residual, not the slope, are what answer the
question. A constant delay puts both near zero, and only then does the
slope mean anything; where they are large the phase is not a straight line
and the fitted "delay" is an artefact of fitting one to it. The median
coherence in the band says how much of the pair a linear model could
describe at all, and the parabolic estimate from align.estimate is
reported alongside for comparison.

Control: the reference delayed by a known fractional offset (the operator
applied by fractional_correct.py) must return that offset at coherence 1.0
with a near-zero intercept and residual.

The defaults cover every item's reference against the same test variants as
the sensitivity study, plus the synthetic control; analysis/analysis.R
reads the resulting table.

Usage:
    python src/subsample_phase_slope.py \
        --prep-root <prepared stimulus tree>/prep_60s \
        --out <...>/data/subsample_phase_slope.csv \
        [--items ...] [--variants ...] [--synthetic 0.3] \
        [--fmin 100] [--fmax 8000]
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from align import estimate                          # noqa: E402
from subsample_sensitivity import (ITEMS, TEST_VARIANTS,   # noqa: E402
                                   fractional_delay)

REF_VARIANT = "7OA"
# Same items and test variants as the sensitivity study, so that the two
# tables describe the same pairs.
DEFAULT_ITEMS = list(ITEMS)
DEFAULT_VARIANTS = [v for v in TEST_VARIANTS if v != REF_VARIANT]

FIELDS = ["item", "variant", "kind", "injected_samples", "lag_samples",
          "parabolic_subsample", "delay_est_samples", "phase_offset_rad",
          "resid_rms_rad", "median_coherence"]


def phase_slope_delay(ref: np.ndarray, test: np.ndarray, fs: int,
                      n_windows: int = 15, window_s: float = 10.0,
                      fmin: float = 100.0, fmax: float = 8000.0
                      ) -> tuple[float, float, float, float]:
    """Coherence-weighted phase-slope estimate of a constant delay.

    Returns (delay in samples that ``test`` is delayed relative to ``ref``,
    median magnitude-squared coherence in [fmin, fmax], fitted phase
    intercept in radians, weighted RMS fit residual in radians). The last
    two say whether the constant-delay model holds at all: a true delay
    gives an intercept and a residual near zero, and only then is the
    delay itself meaningful.
    """
    n = min(len(ref), len(test))
    win = int(window_s * fs)
    if n < win:
        raise ValueError(f"signal shorter than the {window_s:g} s analysis "
                         f"window ({n} samples); pass a longer excerpt or "
                         f"reduce window_s")
    starts = np.clip(np.linspace(0.02 * n, 0.95 * n - win, n_windows).astype(int),
                     0, max(n - win, 0))
    w = np.hanning(win)
    Sxy = Sxx = Syy = None
    for s in starts:
        a = ref[s:s + win].mean(axis=1)
        b = test[s:s + win].mean(axis=1)
        if a.std() < 1e-9 or b.std() < 1e-9:       # skip silent windows
            continue
        A = np.fft.rfft(a * w)
        B = np.fft.rfft(b * w)
        Sxy = A * np.conj(B) if Sxy is None else Sxy + A * np.conj(B)
        Sxx = np.abs(A) ** 2 if Sxx is None else Sxx + np.abs(A) ** 2
        Syy = np.abs(B) ** 2 if Syy is None else Syy + np.abs(B) ** 2
    if Sxy is None:
        raise ValueError("no usable (non-silent) analysis window")
    f = np.fft.rfftfreq(win, 1 / fs)
    coh = np.abs(Sxy) ** 2 / np.maximum(Sxx * Syy, 1e-30)
    band = (f >= fmin) & (f <= fmax)
    ph = np.unwrap(np.angle(Sxy[band]))
    wgt = coh[band] ** 2
    # Weighted LS fit of ph = intercept + delay * x, with x = 2*pi*f/fs.
    # With Sxy = A*conj(B), a delayed test gives a positive slope. The
    # intercept absorbs the 2*pi*k that np.unwrap leaves undetermined.
    x = 2 * np.pi * f[band] / fs
    W = wgt.sum()
    Sw_x, Sw_y = (wgt * x).sum(), (wgt * ph).sum()
    Sw_xx, Sw_xy = (wgt * x * x).sum(), (wgt * x * ph).sum()
    slope = float((W * Sw_xy - Sw_x * Sw_y) / (W * Sw_xx - Sw_x ** 2))
    intercept = float((Sw_y - slope * Sw_x) / W)
    resid = ph - (intercept + slope * x)
    resid_rms = float(np.sqrt((wgt * resid ** 2).sum() / W))
    return slope, float(np.median(coh[band])), intercept, resid_rms


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--prep-root", required=True,
                    help="root of the prepared (conditioned) stimulus tree")
    ap.add_argument("--out", required=True, help="output CSV")
    ap.add_argument("--items", nargs="+", default=DEFAULT_ITEMS)
    ap.add_argument("--variants", nargs="+", default=DEFAULT_VARIANTS,
                    help="test variants compared against the reference")
    ap.add_argument("--synthetic", type=float, default=0.3,
                    help="known delay (samples) applied to the reference as "
                         "the control pair; 0 disables the control")
    ap.add_argument("--fmin", type=float, default=100.0,
                    help="lower edge of the fitted band, Hz")
    ap.add_argument("--fmax", type=float, default=8000.0,
                    help="upper edge of the fitted band, Hz")
    args = ap.parse_args()

    prep = Path(args.prep_root).expanduser()
    out = Path(args.out).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)

    rows = []
    for item in args.items:
        ref, fs = sf.read(prep / item / f"{item}_{REF_VARIANT}.wav",
                          always_2d=True, dtype="float64")
        pairs = []
        if args.synthetic != 0.0:
            pairs.append((f"{REF_VARIANT}+{args.synthetic:g}", "synthetic",
                          args.synthetic, fractional_delay(ref, args.synthetic)))
        for v in args.variants:
            t, _ = sf.read(prep / item / f"{item}_{v}.wav",
                           always_2d=True, dtype="float64")
            pairs.append((v, "real", "", t))
        for variant, kind, injected, test in pairs:
            r = estimate(ref, test, fs=fs)
            d, coh, off, rms = phase_slope_delay(ref, test, fs,
                                                 fmin=args.fmin, fmax=args.fmax)
            rows.append({"item": item, "variant": variant, "kind": kind,
                         "injected_samples": injected, "lag_samples": r.lag,
                         "parabolic_subsample": round(r.subsample, 4),
                         "delay_est_samples": round(d, 4),
                         "phase_offset_rad": round(off, 3),
                         "resid_rms_rad": round(rms, 3),
                         "median_coherence": round(coh, 3)})
            print(f"{item:14s} {variant:10s} {kind:9s} parabolic lag={r.lag} "
                  f"sub={r.subsample:+.4f} | phase-slope {d:+.4f} smp "
                  f"(intercept {off:+.2f} rad, residual {rms:.2f} rad, "
                  f"median coherence {coh:.3f})")

    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)
    print(f"-> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
