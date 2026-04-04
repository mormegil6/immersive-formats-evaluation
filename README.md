[![R](https://img.shields.io/badge/R-4.0+-blue.svg)]() [![tidyverse](https://img.shields.io/badge/tidyverse-2.0-blue.svg)]() [![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](http://creativecommons.org/licenses/by-nc-sa/4.0/)

# Immersive Audio Formats Benchmarking - Supplementary Materials

Supplementary materials for the paper: **"Objective evaluation of immersive audio formats using BAM-Q and BINAQUAL binaural quality models: a case study with higher-order Ambisonics"**

This repository contains:
- Raw benchmarking data (BAM-Q and BINAQUAL model predictions)
- Reproducible statistical analysis script
- Analysis outputs

For methodology, interpretation, and results discussion, please refer to the main paper.

## Repository Structure

```
.
├── data/
│   ├── benchmarking.txt           # Raw model predictions (11 formats, 15 metrics)
├── rdocs/
│   ├── statistical_analysis.R     # Reproducible analysis script
├── results/
│   └── analysis_report.md         # Complete analysis output
└── README.md
```

## Data

**Data file**: `data/benchmarking.txt`  
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

- the input signals for the benchmarking analysis are binaural renders of the [*"Deus Ex Machina"*](https://push.fm/fl/achpg-deusexmachina) 7OA choral recording, encoded to various immersive audio formats
- The analysis script uses algorithmic metric selection (correlation-based) with no hard-coded parameters
- All analytical choices are justified in the paper
- The analysis pipeline can be adapted for different datasets by replacing `data/benchmarking.txt`

## License

This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License][cc-by-nc-sa].

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg

## Contact

For questions regarding this supplementary material, please contact me via e-mail: bartlomiej.mroz@pg.edu.pl

