[![R](https://img.shields.io/badge/R-4.0+-blue.svg)]() [![tidyverse](https://img.shields.io/badge/tidyverse-2.0-blue.svg)]() [![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

# Immersive Audio Formats Evaluation - Supplementary Materials

Supplementary materials for the paper:

***"Objective evaluation of immersive audio formats using BAM-Q and BINAQUAL binaural quality models: a case study with higher-order Ambisonics"***  
Bartłomiej Mróz · *Applied Acoustics*, Elsevier, 2026 [under review]

This repository contains:
- Raw evaluation data (BAM-Q and BINAQUAL model predictions)
- Reproducible statistical analysis script
- Analysis outputs

For methodology, interpretation, and results discussion, please refer to the main paper.

## Repository Structure

```
.
├── data/
│   ├── evaluation.txt           # Raw model predictions (11 formats, 15 metrics)
├── rdocs/
│   ├── statistical_analysis.R     # Reproducible analysis script
├── results/
│   └── analysis_report.md         # Complete analysis output
└── README.md
```

## Data

**Data file**: `data/evaluation.txt`  
**Formats**: 11 immersive audio formats (including 7OA reference)  
**Metrics**: BAM-Q and BINAQUAL model predictions  
**Test signal**: 7OA choral recording

The analysis algorithmically selects 4 independent metrics (|r| < 0.80) for statistical analysis, then applies a two-tier structure: composite perceptual metrics (`overall_measure`, `LS`) are used for primary rankings and Euclidean distance, while spatial sub-metrics (`ILDdiff`, `ITDdiff`) are reported diagnostically. See the paper for detailed metric selection rationale.

## Reproducing the Analysis

### Prerequisites

```r
install.packages("tidyverse")
```

### Run the Analysis

```bash
Rscript rdocs/statistical_analysis.R
```

The script performs the complete statistical analysis pipeline described in the paper:
1. Data import and validation
2. Redundancy detection and metric selection (correlation threshold |r| < 0.80)
3. Two-tier metric structure (primary: `overall_measure` + `LS`; diagnostic: `ILDdiff` + `ITDdiff`)
4. Summary statistics
5. Euclidean distance from reference (primary metrics only, to avoid double-counting)
6. Format rankings (2-metric primary and 4-metric comparison, with rank change)
7. Spatial cue asymmetry analysis (ILD vs ITD, diagnostic)
8. Correlation analysis (descriptive r, no p-values — exhaustive dataset)
9. BINAQUAL LS metric behavior (product vs mean formulation analysis)
10. Within-category metric discrimination (Ambisonics vs channel/object-based)
11. Quality space data (overall_measure vs LS for 2D scatter)

**Output**: Console text with all analysis results (also available in `results/analysis_report.md`)

## Citation

If you use this data or analysis code, please cite the main paper:

```
[BibTeX citation will be added upon publication]
```

## Notes

- the input signals for the evaluation are binaural renders of the [*"Deus Ex Machina"*](https://push.fm/fl/achpg-deusexmachina) 7OA choral recording, encoded to various immersive audio formats
- The analysis script uses algorithmic metric selection (correlation-based) with no hard-coded parameters
- All analytical choices are justified in the paper
- The analysis pipeline can be adapted for different datasets by replacing `data/evaluation.txt`
- An interactive browser-based visualizer for the IKO loudspeaker layout used in the evaluation is available at [mormegil6.github.io/42p-IKO-visualization](https://mormegil6.github.io/42p-IKO-visualization/)

## License

This work is licensed under a [Creative Commons Attribution 4.0 International License][cc-by].

[![CC BY 4.0][cc-by-image]][cc-by]

[cc-by]: https://creativecommons.org/licenses/by/4.0/
[cc-by-image]: https://i.creativecommons.org/l/by/4.0/88x31.png
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg

## Contact

Bartłomiej Mróz · bartlomiej.mroz@pg.edu.pl · Department of Multimedia Systems, Gdańsk University of Technology · [bmroz.eu](https://bmroz.eu)

