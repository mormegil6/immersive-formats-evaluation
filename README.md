[![R](https://img.shields.io/badge/R-4.0+-blue.svg)]() [![Python](https://img.shields.io/badge/Python-3.11-blue.svg)]() [![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

# Latency and Anchor Dependence in Objective Binaural Quality Metrics - Supplementary Materials

Supplementary materials for the paper:

***"Latency and anchor dependence in objective binaural quality metrics: a cross-format evaluation of immersive audio"***  
Bartłomiej Mróz · Przemysław Danowski · *Applied Acoustics*, Elsevier, 2026 [under review]

This repository contains:
- The complete stimulus conditioning and scoring pipeline
- Scored BAM-Q and BINAQUAL model predictions for every format, content item and reference anchor
- The reproducible statistical analysis, and the per-figure data tables behind every figure in the paper

For methodology, interpretation, and results discussion, please refer to the main paper.

## Repository Structure

```
.
├── data/
│   ├── stimuli.csv                    # stimulus inventory (item x format variant)
│   ├── metrics_long.csv               # primary scored results (aligned stimuli)
│   ├── metrics_long_noalign.csv       # control arm, renderer latency left uncompensated
│   ├── metrics_long_segments.csv      # five-window segmented arm
│   ├── conditioning_*.csv             # alignment and loudness diagnostics per run
│   └── pairs*.csv                     # reference/test pair definitions
├── pipeline/
│   ├── src/                           # conditioning and scoring
│   ├── analysis/                      # statistical analysis and figures (R)
│   ├── tbe/                           # ambiX -> TBE encoding and offline rendering
│   ├── run_all.sh                     # conditioning + scoring
│   ├── run_analysis.sh                # analysis + figures + values.tex
│   └── requirements.txt
├── results/
│   ├── analysis_report.md             # full analysis output, generated
│   ├── figure_data/                   # one table per figure
│   └── figures/                       # the figures as published
└── README.md
```

## Data

**Content items**: 3 professionally produced recordings, differing in genre and in how their Ambisonic masters were assembled  
**Format variants**: 11, including the 7OA master used as the primary reference anchor  
**Reference anchors**: 3 (7OA, 5OA, native Dolby Atmos), each scored against every variant  
**Models**: BAM-Q (perceptual quality) and BINAQUAL (localisation similarity)

The design is a randomized complete block: format variants are the treatments and content items are the blocks, with each format evaluated once per item. `metrics_long.csv` is the primary arm; `metrics_long_noalign.csv` repeats it identically except that renderer transport latency is left uncompensated, which isolates the effect of alignment; `metrics_long_segments.csv` repeats it over five windows per item.

The `conditioning_*.csv` tables record what the conditioning stage did to each signal -- estimated lag, polarity, cross-correlation peak ratio, residual lag after correction, integrated loudness before normalisation, applied gain and resulting true peak -- so that every conditioning decision is auditable rather than implicit.

## Reproducing the Analysis

The statistical analysis runs from the scored results in `data/` and needs only base R. Re-running the scoring stage additionally needs Python, MATLAB and the two models.

### Analysis only

```bash
Rscript pipeline/analysis/analysis.R data results/figure_data values.tex
```

This regenerates every figure, every per-figure data table, and the macro file consumed by the manuscript. All values reported in the paper are emitted as LaTeX macros rather than transcribed, so the manuscript cannot drift from the analysis.

Passing a fourth argument writes a readable transcript of the run:

```bash
Rscript pipeline/analysis/analysis.R data results/figure_data values.tex results/analysis_report.md
```

`results/analysis_report.md` is a verbatim capture of that output rather than a hand-written summary, so it cannot disagree with the numbers the analysis produced. `results/figures/` holds the figures as they appear in the paper, so a regenerated figure can be compared against the published one.

### Full pipeline, including scoring

```bash
pip install -r pipeline/requirements.txt
./pipeline/run_all.sh          # conditioning + scoring
./pipeline/run_analysis.sh     # analysis + figures
```

Scoring additionally requires:
- **BAM-Q** -- MATLAB implementation, obtained from its authors
- **BINAQUAL** -- Python implementation
- **Audio360 SDK** -- only for rebuilding the TBE variant; see `pipeline/tbe/README.md`

The binaural stimuli themselves are not redistributed here, as they derive from commercially released productions.

## Pipeline

1. **Conditioning** (`src/prepare_stimuli.py`) -- estimates and removes the transport latency each renderer introduces, corrects polarity, applies a common crop, and normalises every signal to a common integrated loudness (ITU-R BS.1770) by scalar gain, without limiting or dynamics processing.
2. **Alignment** (`src/align.py`) -- generalised cross-correlation over 15 windows, coherently averaged so that a single ambiguous peak cannot dominate the estimate. Reports the peak ratio and the residual lag after correction.
3. **Loudness** (`src/loudness.py`) -- self-contained ITU-R BS.1770 implementation, validated against `ffmpeg`'s `ebur128`.
4. **Scoring** (`src/run_bamq.m`, `src/run_binaqual.py`) -- each reference/test pair scored by both models.
5. **Analysis** (`analysis/analysis.R`) -- rankings, cross-content concordance, anchor sensitivity, and cue diagnostics referred to discrimination thresholds.

Outputs are written deterministically: float WAVs are stripped of the wall-clock timestamp libsndfile writes into the PEAK chunk, so a re-run of the conditioning stage is bit-reproducible.

## Citation

If you use this data or analysis code, please cite the main paper:

```
[BibTeX citation will be added upon publication]
```

## Notes

- the input signals for the evaluation are binaural renders of three recordings, among them the [*"Deus Ex Machina"*](https://push.fm/fl/achpg-deusexmachina) 7OA choral production, encoded to various immersive audio formats
- All values reported in the paper are generated by `analysis.R` and consumed as LaTeX macros; none are transcribed by hand
- Kendall's coefficient of concordance is reported with a Monte-Carlo permutation p-value alongside the chi-squared approximation, the latter being unreliable with three blocks
- The analysis pipeline can be adapted for different datasets by replacing the contents of `data/`
- An interactive browser-based visualizer for the IKO loudspeaker layout used in the evaluation is available at [bmroz.eu/tools/42p-IKO-visualization](https://bmroz.eu/tools/42p-IKO-visualization/)

## License

This work is licensed under a [Creative Commons Attribution 4.0 International License][cc-by].

[![CC BY 4.0][cc-by-image]][cc-by]

[cc-by]: https://creativecommons.org/licenses/by/4.0/
[cc-by-image]: https://i.creativecommons.org/l/by/4.0/88x31.png
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg

The Meta Audio360 SDK is **not** covered by this licence and is not included in this repository; see `pipeline/tbe/README.md`.

## Contact

Bartłomiej Mróz · bartlomiej.mroz@pg.edu.pl · Department of Multimedia Systems, Gdańsk University of Technology · [bmroz.eu](https://bmroz.eu)
