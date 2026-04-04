# Immersive Audio Benchmarking - Statistical Analysis Results

## 1. Dataset Overview
- Total formats analyzed: 11 
- Reference formats: 7OA-MagLS
- Non-commercial formats: 42pIKO-MagLS 
- Commercial formats: 1OA-YT, Atmos-native, 42pIKO-Atmos, Auro3D-native, 42pIKO-Auro3D, 3OA-IAMF, Sony360RA-native, 42pIKO-Sony360RA, 2OA-TBE 


## 2. Raw Data

             test SNR_dc SNR_ac SNR_dc_fix SNR_ac_fix    OPM OPM_fix binQ ILDdiff   ITDdiff IVSdiff overall_measure vnsim_0 vnsim_1      LS
           1OA-YT  1.230  2.933      1.230     0.7318  50.33   62.62   64    2536 1.479e-04 0.02886          0.4992  0.2231  0.2234 0.04985
     42pIKO-MagLS  1.091  4.332      1.091     0.5052  45.64   66.33   49    6454 1.093e-04 0.02658          0.3822  0.2624  0.2627 0.06891
     Atmos-native  2.057  4.699      2.057     0.2932  41.74   59.35   48    6517 1.151e-04 0.02595          0.3744  0.2165  0.2136 0.04623
     42pIKO-Atmos  2.147  4.553      2.147     0.1768  41.89   59.56   69    3395 9.297e-05 0.02265          0.4976  0.2104  0.2090 0.04396
    Auro3D-native  1.365  3.649      1.365     0.5818  47.03   62.75   60    4267 9.226e-05 0.03416          0.4680  0.2188  0.2154 0.04713
    42pIKO-Auro3D  1.356  4.335      1.356     0.4282  44.78   64.32   46    5490 1.068e-04 0.04949          0.3588  0.2093  0.2098 0.04390
         3OA-IAMF  1.685  2.318      1.685     0.8394  51.03   58.06   88    1436 5.699e-05 0.01048          0.4865  0.2279  0.2298 0.05238
 Sony360RA-native  5.603  4.407      5.603     0.5752  34.76   41.90   50    6383 1.084e-04 0.02612          0.3448  0.2281  0.2284 0.05209
 42pIKO-Sony360RA  9.585  3.509      9.585     0.7573  29.99   32.60   65    3488 8.492e-05 0.03341          0.2358  0.2151  0.2147 0.04618
          2OA-TBE  4.363  3.057      4.363     0.9246  40.07   44.71   75    2385 6.885e-05 0.02588          0.3730  0.3889  0.3833 0.14905
        7OA-MagLS  0.000  0.000      0.000     0.0000 715.40  725.56  100       0 0.000e+00 0.00000          0.7226  1.0000  1.0000 1.00000


## 3. Metric Selection and Redundancy Removal

Full correlation matrix (all available metrics):

    Excluding SNR_dc (r=1.000 with SNR_dc_fix, keeping _fix version)
    Excluding OPM (r=1.000 with OPM_fix, keeping _fix version)
    Excluding vnsim_1 (r=1.000 with vnsim_0, perfectly correlated)

                SNR_ac SNR_dc_fix SNR_ac_fix OPM_fix   binQ ILDdiff ITDdiff IVSdiff overall_measure vnsim_0     LS
    SNR_ac           1.000      0.250      0.124  -0.823 -0.892   0.874   0.780   0.720          -0.736  -0.847 -0.843
    SNR_dc_fix       0.250      1.000      0.460  -0.382 -0.160   0.146   0.095   0.262          -0.724  -0.303 -0.320
    SNR_ac_fix       0.124      0.460      1.000  -0.629 -0.074  -0.031   0.286   0.286          -0.539  -0.503 -0.563
    OPM_fix         -0.823     -0.382     -0.629   1.000  0.660  -0.575  -0.762  -0.670           0.791   0.971  0.991
    binQ            -0.892     -0.160     -0.074   0.660  1.000  -0.954  -0.827  -0.807           0.700   0.702  0.690
    ILDdiff          0.874      0.146     -0.031  -0.575 -0.954   1.000   0.684   0.635          -0.660  -0.615 -0.604
    ITDdiff          0.780      0.095      0.286  -0.762 -0.827   0.684   1.000   0.700          -0.556  -0.807 -0.796
    IVSdiff          0.720      0.262      0.286  -0.670 -0.807   0.635   0.700   1.000          -0.711  -0.686 -0.683
    overall_measure -0.736     -0.724     -0.539   0.791  0.700  -0.660  -0.556  -0.711           1.000   0.733  0.756
    vnsim_0         -0.847     -0.303     -0.503   0.971  0.702  -0.615  -0.807  -0.686           0.733   1.000  0.993
    LS              -0.843     -0.320     -0.563   0.991  0.690  -0.604  -0.796  -0.683           0.756   0.993  1.000

### Independent metrics with |r| < 0.80 threshold:
      1. SNR_dc_fix (BAM-Q signal-to-noise ratio (DC component))
      2. SNR_ac_fix (BAM-Q signal-to-noise ratio (AC component))
      3. ILDdiff (BAM-Q interaural level difference)
      4. IVSdiff (BAM-Q interaural vector strength difference)
      5. ITDdiff (BAM-Q interaural time difference)
      6. overall_measure (BAM-Q composite perceptual quality)
      7. LS (BINAQUAL localization similarity)

### Excluded 4 metrics due to high correlation (|r| >= 0.80):
      binQ, SNR_ac, vnsim_0, OPM_fix

### Excluding metrics based on BAM-Q paper:
      SNR_dc_fix, SNR_ac_fix, IVSdiff

Rationale:
- SNR_dc_fix, SNR_ac_fix: Signal-to-noise ratios quantifying signal power preservation rather than perceptual quality degradation (Fleßner et al., 2019).
- IVSdiff: Binaural coherence measure conceptually redundant with selected ILDdiff/ITDdiff spatial cue metrics.
- The 4 selected metrics provide complete perceptual coverage: overall quality (overall_measure), localization (LS), amplitude cues (ILDdiff), temporal cues (ITDdiff).

### Selected 4 metrics for analysis:
      1. ILDdiff (BAM-Q interaural level difference)
      2. ITDdiff (BAM-Q interaural time difference)
      3. overall_measure (BAM-Q composite perceptual quality)
      4. LS (BINAQUAL localization similarity)

### Two-tier analysis structure:
- **(a) PRIMARY**: `overall_measure` + `LS` (composite perceptual metrics)  
  Used for Euclidean distance and rankings to avoid double-counting.  
  Rationale: `overall_measure` (BAM-Q) already incorporates ILDdiff/ITDdiff internally; including them separately inflates binaural cue weight.
- **(b) DIAGNOSTIC**: `ILDdiff` + `ITDdiff` (explanatory sub-metrics)  
  Reported separately for spatial cue analysis.

### Correlation validation for selected metric set:

                ILDdiff ITDdiff overall_measure     LS
    ILDdiff           1.000   0.684          -0.660 -0.604
    ITDdiff           0.684   1.000          -0.556 -0.796
    overall_measure  -0.660  -0.556           1.000  0.756
    LS               -0.604  -0.796           0.756  1.000

### Key pairwise correlations:
      ITDdiff <-> LS: r = -0.796
      Maximum |r| in 4-metric set: 0.796
    All pairwise correlations |r| < 0.80 confirmed.


## 4. Summary Statistics (4 Metrics)

          metric    Min       Max     Range      Mean    Median        SD
         ILDdiff 0.0000 6.517e+03 6.517e+03 3.850e+03 3.488e+03 2.192e+03
         ITDdiff 0.0000 1.479e-04 1.479e-04 8.942e-05 9.297e-05 3.829e-05
              LS 0.0439 1.000e+00 9.561e-01 1.454e-01 4.985e-02 2.851e-01
 overall_measure 0.2358 7.226e-01 4.868e-01 4.312e-01 3.822e-01 1.258e-01


## 5. Euclidean Distance from Reference (Primary Metrics Only)

> Using only composite perceptual metrics (`overall_measure`, `LS`) to avoid double-counting ILDdiff/ITDdiff which are internal to BAM-Q overall_measure.

             test euclidean_distance
           1OA-YT              3.777
     42pIKO-Atmos              3.801
         3OA-IAMF              3.818
           Auro3D              3.908
          2OA-TBE              4.078
           42pIKO              4.242
            Atmos              4.342
    42pIKO-Auro3D              4.429
        Sony360RA              4.481
 42pIKO-Sony360RA              5.116


## 6. Format Rankings (1 = Best)

> Primary ranking uses only composite metrics (`overall_measure`, `LS`). Old 4-metric ranking shown for comparison.

             test rank_overall rank_LS avg_rank_2m avg_rank_4m rank_change
         7OA ref.            1       1         1.0         1.0         0.0
           1OA-YT            2       6         4.0         5.8         1.8
         3OA-IAMF            4       4         4.0         3.0        -1.0
           42pIKO            6       3         4.5         7.0         2.5
          2OA-TBE            8       2         5.0         4.0        -1.0
           Auro3D            5       7         6.0         6.0         0.0
     42pIKO-Atmos            3      10         6.5         6.0        -0.5
            Atmos            7       8         7.5         9.0         1.5
        Sony360RA           10       5         7.5         8.0         0.5
    42pIKO-Auro3D            9      11        10.0         8.8        -1.2
 42pIKO-Sony360RA           11       9        10.0         7.5        -2.5


## 7. Spatial Cue Asymmetry (ILD vs ITD) [DIAGNOSTIC]

> ILDdiff and ITDdiff are shown as diagnostic/explanatory sub-metrics. They are NOT included in the primary quality ranking to avoid double-counting with overall_measure (BAM-Q composite), which incorporates them internally.

        Metric     Value
1       ILD_CV 5.692e-01
2       ITD_CV 4.282e-01
3     CV_Ratio 1.329e+00
4    ILD_Range 6.517e+03
5    ITD_Range 1.479e-04
6  Range_Ratio 4.405e+07
7       ILD_SD 2.192e+03
8       ITD_SD 3.829e-05
9     SD_Ratio 5.724e+07
10    ILD_Fold 4.537e+00
11    ITD_Fold 2.596e+00


## 8. Overall vs Localization Correlation (Descriptive)

> Pearson r reported as descriptive statistic only (exhaustive dataset, n=11). No p-values: observations are non-independent and not sampled from a population.

- (a) All formats incl. reference (n = 11): r = 0.756
- (b) All formats excl. reference (n = 10): r = -0.120
- (c) Ambisonics-based excl. reference (n = 3): r = -0.998  
  Formats: 1OA-YT, 3OA-IAMF, 2OA-TBE
- (d) Channel/object-based excl. reference (n = 7): r = -0.064  
  Formats: 42pIKO, Atmos, 42pIKO-Atmos, Auro3D, 42pIKO-Auro3D, Sony360RA, 42pIKO-Sony360RA


## 9. BINAQUAL LS Metric Behavior

> BINAQUAL was validated for within-order codec comparison (e.g., compressed vs uncompressed FOA). The cross-format paradigm (all formats vs 7OA reference) depresses all vnsim values, and the LS = vnsim_0 × vnsim_1 product compounds this compression.

### 9a. Raw localization similarity components:

             test vnsim_0 vnsim_1      LS LS_check LS_mean
           1OA-YT  0.2231  0.2234 0.04985  0.04985  0.2233
           42pIKO  0.2624  0.2627 0.06891  0.06891  0.2625
            Atmos  0.2165  0.2136 0.04623  0.04623  0.2150
     42pIKO-Atmos  0.2104  0.2090 0.04396  0.04396  0.2097
           Auro3D  0.2188  0.2154 0.04713  0.04713  0.2171
    42pIKO-Auro3D  0.2093  0.2098 0.04390  0.04390  0.2095
         3OA-IAMF  0.2279  0.2298 0.05238  0.05238  0.2289
        Sony360RA  0.2281  0.2284 0.05209  0.05209  0.2282
 42pIKO-Sony360RA  0.2151  0.2147 0.04618  0.04618  0.2149
          2OA-TBE  0.3889  0.3833 0.14905  0.14905  0.3861
         7OA ref.  1.0000  1.0000 1.00000  1.00000  1.0000

### 9b. Formula verification: LS = vnsim_0 × vnsim_1
    Max |LS - vnsim_0*vnsim_1| = 1.74e-07 (confirmed, floating-point precision)

### 9c. Rankings comparison (product vs mean, excluding reference):

             test      LS rank_LS_product LS_mean rank_LS_mean
          2OA-TBE 0.14905               1  0.3861            1
           42pIKO 0.06891               2  0.2625            2
         3OA-IAMF 0.05238               3  0.2289            3
        Sony360RA 0.05209               4  0.2282            4
           1OA-YT 0.04985               5  0.2233            5
           Auro3D 0.04713               6  0.2171            6
            Atmos 0.04623               7  0.2150            7
 42pIKO-Sony360RA 0.04618               8  0.2149            8
     42pIKO-Atmos 0.04396               9  0.2097            9
    42pIKO-Auro3D 0.04390              10  0.2095           10

### 9d. Correlation of overall_measure with LS variants (descriptive r):
    Incl. reference:  LS_product r = 0.756,  LS_mean r = 0.734
    Excl. reference:  LS_product r = -0.120,  LS_mean r = -0.117

### 9e. Dynamic range (non-reference formats):
    LS_product: min = 0.0439, max = 0.1490, range = 0.1051
    LS_mean:    min = 0.2095, max = 0.3861, range = 0.1765
    Ratio (mean/product range): 1.7x wider dynamic range with mean formulation


## 10. Within-Category Metric Discrimination

> CV (SD/mean) per metric within each format family. CV > 0.15 = good discrimination, CV < 0.15 = poor discrimination within that group.

- **Ambisonics-based** (n = 3): 1OA-YT, 3OA-IAMF, 2OA-TBE
- **Channel/object-based** (n = 7): 42pIKO, Atmos, 42pIKO-Atmos, Auro3D, 42pIKO-Auro3D, Sony360RA, 42pIKO-Sony360RA

### 10a. Ambisonics-based formats:

          metric       min       max      mean        SD     CV
 overall_measure 3.730e-01 4.992e-01 4.529e-01 6.947e-02 0.1534
              LS 4.985e-02 1.490e-01 8.376e-02 5.656e-02 0.6752
         ILDdiff 1.436e+03 2.536e+03 2.119e+03 5.961e+02 0.2813
         ITDdiff 5.699e-05 1.479e-04 9.126e-05 4.945e-05 0.5418

    Discriminating (CV > 0.15): overall_measure, LS, ILDdiff, ITDdiff
    Poor discrimination (CV <= 0.15): (none)

### 10b. Channel/object-based formats:

          metric       min       max      mean        SD     CV
 overall_measure 2.358e-01 4.976e-01 3.802e-01 8.571e-02 0.2254
              LS 4.390e-02 6.891e-02 4.977e-02 8.873e-03 0.1783
         ILDdiff 3.395e+03 6.517e+03 5.142e+03 1.404e+03 0.2730
         ITDdiff 8.492e-05 1.151e-04 1.014e-04 1.122e-05 0.1107

    Discriminating (CV > 0.15): overall_measure, LS, ILDdiff
    Poor discrimination (CV <= 0.15): ITDdiff

### 10c. CV comparison (Ambisonics vs Channel/Object):

          metric CV_ambisonics CV_channel_obj ratio  better_for
 overall_measure         0.153          0.225  0.68 Channel/Obj
              LS         0.675          0.178  3.79  Ambisonics
         ILDdiff         0.281          0.273  1.03  Ambisonics
         ITDdiff         0.542          0.111  4.90  Ambisonics


## 11. Quality Space Data (overall_measure vs LS)

> Format-level data for 2D scatter plot (overall perceptual quality vs localization).

             test overall_measure      LS
         7OA ref.          0.7226 1.00000
           1OA-YT          0.4992 0.04985
     42pIKO-Atmos          0.4976 0.04396
         3OA-IAMF          0.4865 0.05238
           Auro3D          0.4680 0.04713
           42pIKO          0.3822 0.06891
            Atmos          0.3744 0.04623
          2OA-TBE          0.3730 0.14905
    42pIKO-Auro3D          0.3588 0.04390
        Sony360RA          0.3448 0.05209
 42pIKO-Sony360RA          0.2358 0.04618
