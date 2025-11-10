# Immersive Audio Formats Benchmarking - Supplementary Materials

[![R](https://img.shields.io/badge/R-4.0+-blue.svg)]() [![tidyverse](https://img.shields.io/badge/tidyverse-2.0-blue.svg)]() [![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](http://creativecommons.org/licenses/by-nc-sa/4.0/)

Supplementary materials for the paper: **"Benchmarking Widely Adopted Immersive Audio Formats Using Objective Binaural Quality Metrics"**

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
**Formats**: 11 immersive audio formats (including 7OA-MagLS reference)  
**Metrics**: BAM-Q and BINAQUAL model predictions  
**Test signal**: DeusExMachina orchestral excerpt

The analysis algorithmically selects 4 independent metrics (|r| < 0.80) for statistical analysis. See the paper for detailed metric selection rationale.

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
2. Redundancy detection and metric selection
3. Summary statistics
4. Deviation from reference (Euclidean distance)
5. Format rankings
6. Spatial asymmetry analysis (ILD vs ITD)
7. Correlation analysis
8. Principal component analysis

**Output**: Console text with all analysis results (also available in `results/analysis_report.md`)

## Citation

If you use this data or analysis code, please cite the main paper:

```
[BibTeX citation will be added upon publication]
```

## Notes

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

For questions regarding this supplementary material, please address to me via e-mail: bartlomiej.mroz@pg.edu.pl

