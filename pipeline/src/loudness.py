"""Integrated loudness measurement per ITU-R BS.1770-4 / EBU R 128.

Self-contained implementation (no external binaries) so that the stimulus
conditioning step of the benchmarking pipeline is reproducible from source.

The K-weighting filter coefficients are the normative 48 kHz values given in
ITU-R BS.1770-4, Tables 1 and 2.  Because every stimulus in this study is
48 kHz, the coefficients are used directly rather than re-derived; the
sample-rate guard below makes that assumption explicit.

Reference
---------
ITU-R BS.1770-4 (2015), "Algorithms to measure audio programme loudness and
true-peak audio level".
"""

from __future__ import annotations

import numpy as np
from scipy.signal import lfilter, resample_poly

# --- Normative K-weighting coefficients at 48 kHz (BS.1770-4, Tables 1-2) ---
_STAGE1_B = np.array([1.53512485958697, -2.69169618940638, 1.19839281085285])
_STAGE1_A = np.array([1.0, -1.69065929318241, 0.73248077421585])
_STAGE2_B = np.array([1.0, -2.0, 1.0])
_STAGE2_A = np.array([1.0, -1.99004745483398, 0.99007225036621])

_BLOCK_S = 0.400          # gating block length (s)
_OVERLAP = 0.75           # gating block overlap
_ABS_GATE = -70.0         # absolute gate (LUFS)
_REL_GATE = -10.0         # relative gate (LU below ungated loudness)
_OFFSET = -0.691          # BS.1770 calibration offset


def k_weight(x: np.ndarray, fs: int) -> np.ndarray:
    """Apply the two-stage BS.1770 K-weighting filter along axis 0."""
    if fs != 48000:
        raise ValueError(
            f"k_weight() ships only the normative 48 kHz coefficients; got {fs} Hz"
        )
    y = lfilter(_STAGE1_B, _STAGE1_A, x, axis=0)
    return lfilter(_STAGE2_B, _STAGE2_A, y, axis=0)


def _block_powers(y: np.ndarray, fs: int) -> np.ndarray:
    """Mean square of each overlapping gating block, summed over channels.

    Returns one value per block (the ``z`` of BS.1770 with unit channel
    weights, which is correct for the L/R pair of a binaural signal).
    """
    block = int(round(_BLOCK_S * fs))
    hop = int(round(block * (1.0 - _OVERLAP)))
    if y.shape[0] < block:
        raise ValueError("signal shorter than one 400 ms gating block")
    starts = np.arange(0, y.shape[0] - block + 1, hop)
    # Cumulative sums give exact block means in O(n) regardless of overlap.
    sq = np.cumsum(np.vstack([np.zeros((1, y.shape[1])), y ** 2]), axis=0)
    z = (sq[starts + block] - sq[starts]) / block   # (n_blocks, n_channels)
    return z.sum(axis=1)


def integrated_lufs(x: np.ndarray, fs: int) -> float:
    """Gated integrated loudness in LUFS.

    Parameters
    ----------
    x : (n_samples, n_channels) float array, full-scale referenced to +/-1.
    fs : sample rate in Hz (must be 48000).
    """
    x = np.atleast_2d(np.asarray(x, dtype=np.float64))
    if x.ndim == 1:
        x = x[:, None]
    z = _block_powers(k_weight(x, fs), fs)

    with np.errstate(divide="ignore"):
        loud = _OFFSET + 10.0 * np.log10(z)

    keep = loud > _ABS_GATE                      # absolute gate
    if not keep.any():
        return float("-inf")
    ungated = _OFFSET + 10.0 * np.log10(z[keep].mean())
    keep &= loud > (ungated + _REL_GATE)         # relative gate
    if not keep.any():
        return float("-inf")
    return float(_OFFSET + 10.0 * np.log10(z[keep].mean()))


def true_peak_dbtp(x: np.ndarray, fs: int, oversample: int = 4) -> float:
    """True-peak level in dBTP (BS.1770-4 Annex 2: >=4x oversampling)."""
    x = np.atleast_2d(np.asarray(x, dtype=np.float64))
    if x.ndim == 1:
        x = x[:, None]
    up = resample_poly(x, oversample, 1, axis=0)
    peak = float(np.max(np.abs(up)))
    return 20.0 * np.log10(peak) if peak > 0 else float("-inf")


def gain_to_target(x: np.ndarray, fs: int, target_lufs: float) -> tuple[np.ndarray, float, float]:
    """Scale ``x`` to ``target_lufs``.

    Returns ``(scaled, measured_lufs_before, gain_db)``.  The operation is a
    pure scalar gain: no limiting, no dynamics processing, so the signal is
    altered only in level.
    """
    before = integrated_lufs(x, fs)
    if not np.isfinite(before):
        raise ValueError("cannot normalise a signal with no gated blocks above -70 LUFS")
    gain_db = target_lufs - before
    return x * (10.0 ** (gain_db / 20.0)), before, gain_db
