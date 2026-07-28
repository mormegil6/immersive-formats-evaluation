"""Latency and polarity estimation between a reference and a test rendering.

Immersive-format renderers (Dolby Atmos Renderer, Auro-3D decoder, FB360,
Resonance, 360 WalkMix Creator, EAR) each impose their own processing latency,
and that latency is *not* a quality degradation -- it is a fixed transport
delay.  Full-reference models that operate on phase (BINAQUAL's NSIM runs on
phaseograms) interpret an uncompensated delay as a total loss of binaural
similarity, so latency must be removed before the models are applied.

Estimation uses generalised cross-correlation over several widely separated
analysis windows.  Agreement across windows distinguishes a constant transport
delay (which can be removed exactly) from clock drift or time-varying
processing (which cannot).
"""

from __future__ import annotations

from dataclasses import dataclass, asdict

import numpy as np


@dataclass
class AlignmentResult:
    lag: int                 # samples the test must be DELAYED by to match ref
    polarity: int            # +1 or -1, applied to the test signal
    corr: float              # correlation at the chosen lag of the averaged GCC
    peak_ratio: float        # peak / next-highest peak of the averaged GCC
    window_lags: list        # per-window lag estimates (diagnostic only)
    window_agreement: float  # fraction of windows within +/-3 smp of the consensus
    subsample: float         # residual sub-sample delay estimate, in samples
    residual_lag: int        # lag remaining after correction (should be 0)
    residual_corr: float     # signed correlation after correction

    def as_dict(self) -> dict:
        d = asdict(self)
        d["window_lags"] = ";".join(str(v) for v in self.window_lags)
        return d


def _gcc(a: np.ndarray, b: np.ndarray, max_lag: int, phat: bool = False) -> np.ndarray:
    """Normalised cross-correlation of a and b for lags in [-max_lag, +max_lag].

    Index k of the returned array corresponds to lag ``k - max_lag``.  A peak at
    lag k means ``a(n) ~ b(n + k)``: the test leads the reference by k samples
    and must be delayed by k to align.
    """
    a = a - a.mean()
    b = b - b.mean()
    n = 1 << int(np.ceil(np.log2(len(a) + 2 * max_lag)))
    A = np.fft.rfft(a, n)
    B = np.fft.rfft(b, n)
    X = A * np.conj(B)
    if phat:
        X /= np.maximum(np.abs(X), 1e-20)
    cc = np.fft.irfft(X, n)
    cc = np.concatenate([cc[-max_lag:], cc[: max_lag + 1]])
    if not phat:
        denom = np.linalg.norm(a) * np.linalg.norm(b)
        if denom > 0:
            cc = cc / denom
    return cc


def _parabolic(cc: np.ndarray, i: int) -> float:
    """Sub-sample peak offset by parabolic interpolation around index i."""
    if i <= 0 or i >= len(cc) - 1:
        return 0.0
    y0, y1, y2 = cc[i - 1], cc[i], cc[i + 1]
    denom = y0 - 2 * y1 + y2
    return 0.0 if denom == 0 else float(0.5 * (y0 - y2) / denom)


def shift(x: np.ndarray, k: int) -> np.ndarray:
    """Delay x by k samples (k > 0 prepends zeros; k < 0 removes leading samples).

    Length is preserved.  Any zero-filled region is later removed by the common
    crop applied in prepare_stimuli.py, so no padding enters the analysis.
    """
    if k == 0:
        return x.copy()
    pad = np.zeros((abs(k), x.shape[1]), dtype=x.dtype)
    return np.vstack([pad, x[:-k]]) if k > 0 else np.vstack([x[-k:], pad])


def _averaged_gcc(ref: np.ndarray, test: np.ndarray, starts: np.ndarray,
                  win: int, max_lag: int) -> tuple[np.ndarray, list[int]]:
    """Coherently average the normalised GCC over several analysis windows.

    Single-window estimates are unreliable on sustained musical material: the
    correlation function often carries several near-equal peaks, and in
    low-contrast windows an ambiguous one wins.  Because the transport delay
    of a renderer is constant while those spurious peaks are not, averaging the
    correlation functions reinforces the true peak and suppresses the rest.
    """
    acc = None
    lags: list[int] = []
    for s in starts:
        a = ref[s:s + win].mean(axis=1)
        b = test[s:s + win].mean(axis=1)
        if a.std() < 1e-9 or b.std() < 1e-9:      # skip silent windows
            continue
        cc = _gcc(a, b, max_lag)
        acc = cc if acc is None else acc + cc
        lags.append(int(np.argmax(np.abs(cc))) - max_lag)
    if acc is None:
        raise ValueError("no usable (non-silent) analysis window")
    return acc / len(lags), lags


def estimate(ref: np.ndarray, test: np.ndarray, fs: int = 48000,
             max_lag_s: float = 2.0, n_windows: int = 15,
             window_s: float = 10.0) -> AlignmentResult:
    """Estimate constant delay and polarity of ``test`` relative to ``ref``."""
    max_lag = int(max_lag_s * fs)
    n = min(len(ref), len(test))
    win = min(int(window_s * fs), max(n // (n_windows + 1), fs))
    starts = np.clip(np.linspace(0.02 * n, 0.95 * n - win, n_windows).astype(int),
                     0, max(n - win, 0))

    cc, lags = _averaged_gcc(ref, test, starts, win, max_lag)
    i = int(np.argmax(np.abs(cc)))
    lag = i - max_lag
    polarity = -1 if cc[i] < 0 else 1

    guard = np.abs(cc).copy()
    guard[max(0, i - 50):i + 51] = 0.0
    peak_ratio = float(abs(cc[i]) / max(guard.max(), 1e-12))
    agreement = float(np.mean([abs(v - lag) <= 3 for v in lags])) if lags else 0.0

    corrected = shift(test * polarity, lag)

    # Confirm on the corrected signal, using the same averaged estimator.
    cc2, _ = _averaged_gcc(ref, corrected, starts, win, max_lag)
    j = int(np.argmax(np.abs(cc2)))
    return AlignmentResult(
        lag=lag,
        polarity=polarity,
        corr=float(abs(cc[i])),
        peak_ratio=peak_ratio,
        window_lags=lags,
        window_agreement=round(agreement, 3),
        subsample=_parabolic(cc2, j),
        residual_lag=int(j - max_lag),
        residual_corr=float(cc2[j]),
    )
