# Immersive Audio Benchmarking - Statistical Analysis Results

## 1. Dataset Overview
    Total formats analyzed: 11 
    Reference formats: 7OA-MagLS 
    Non-commercial formats: 42pIKO-MagLS 
    Commercial formats: 1OA-YT, Atmos-native, 42pIKO-Atmos, Auro3D-native, 42pIKO-Auro3D, 3OA-IAMF, Sony360RA-native, 42pIKO-Sony360RA, 2OA-TBE 


## 2. Raw Data
       test             SNR_dc SNR_ac SNR_dc_fix SNR_ac_fix   OPM OPM_fix  binQ
       <chr>             <dbl>  <dbl>      <dbl>      <dbl> <dbl>   <dbl> <dbl>
     1 1OA-YT             1.23   2.93       1.23      0.732  50.3    62.6    64
     2 42pIKO-MagLS       1.09   4.33       1.09      0.505  45.6    66.3    49
     3 Atmos-native       2.06   4.70       2.06      0.293  41.7    59.3    48
     4 42pIKO-Atmos       2.15   4.55       2.15      0.177  41.9    59.6    69
     5 Auro3D-native      1.36   3.65       1.36      0.582  47.0    62.8    60
     6 42pIKO-Auro3D      1.36   4.33       1.36      0.428  44.8    64.3    46
     7 3OA-IAMF           1.69   2.32       1.69      0.839  51.0    58.1    88
     8 Sony360RA-native   5.60   4.41       5.60      0.575  34.8    41.9    50
     9 42pIKO-Sony360RA   9.59   3.51       9.59      0.757  30.0    32.6    65
    10 2OA-TBE            4.36   3.06       4.36      0.925  40.1    44.7    75
    11 7OA-MagLS          0      0          0         0     715.    726.    100
       ILDdiff   ITDdiff IVSdiff overall_measure vnsim_0 vnsim_1     LS
         <dbl>     <dbl>   <dbl>           <dbl>   <dbl>   <dbl>  <dbl>
     1   2536. 0.000148   0.0289           0.499   0.223   0.223 0.0498
     2   6454. 0.000109   0.0266           0.382   0.262   0.263 0.0689
     3   6517. 0.000115   0.0260           0.374   0.216   0.214 0.0462
     4   3395. 0.0000930  0.0227           0.498   0.210   0.209 0.0440
     5   4267. 0.0000923  0.0342           0.468   0.219   0.215 0.0471
     6   5490. 0.000107   0.0495           0.359   0.209   0.210 0.0439
     7   1436. 0.0000570  0.0105           0.486   0.228   0.230 0.0524
     8   6383. 0.000108   0.0261           0.345   0.228   0.228 0.0521
     9   3488. 0.0000849  0.0334           0.236   0.215   0.215 0.0462
    10   2385. 0.0000688  0.0259           0.373   0.389   0.383 0.149 
    11      0  0          0                0.723   1       1     1     

## 3. Metric Selection and Redundancy Removal
    Full correlation matrix (all available metrics):
      Excluding SNR_dc (r=1.000 with SNR_dc_fix, keeping _fix version)
      Excluding OPM (r=1.000 with OPM_fix, keeping _fix version)
      Excluding vnsim_1 (r=1.000 with vnsim_0, perfectly correlated)

                    SNR_ac SNR_dc_fix SNR_ac_fix OPM_fix   binQ ILDdiff ITDdiff
    SNR_ac           1.000      0.250      0.124  -0.823 -0.892   0.874   0.780
    SNR_dc_fix       0.250      1.000      0.460  -0.382 -0.160   0.146   0.095
    SNR_ac_fix       0.124      0.460      1.000  -0.629 -0.074  -0.031   0.286
    OPM_fix         -0.823     -0.382     -0.629   1.000  0.660  -0.575  -0.762
    binQ            -0.892     -0.160     -0.074   0.660  1.000  -0.954  -0.827
    ILDdiff          0.874      0.146     -0.031  -0.575 -0.954   1.000   0.684
    ITDdiff          0.780      0.095      0.286  -0.762 -0.827   0.684   1.000
    IVSdiff          0.720      0.262      0.286  -0.670 -0.807   0.635   0.700
    overall_measure -0.736     -0.724     -0.539   0.791  0.700  -0.660  -0.556
    vnsim_0         -0.847     -0.303     -0.503   0.971  0.702  -0.615  -0.807
    LS              -0.843     -0.320     -0.563   0.991  0.690  -0.604  -0.796
                    IVSdiff overall_measure vnsim_0     LS
    SNR_ac            0.720          -0.736  -0.847 -0.843
    SNR_dc_fix        0.262          -0.724  -0.303 -0.320
    SNR_ac_fix        0.286          -0.539  -0.503 -0.563
    OPM_fix          -0.670           0.791   0.971  0.991
    binQ             -0.807           0.700   0.702  0.690
    ILDdiff           0.635          -0.660  -0.615 -0.604
    ITDdiff           0.700          -0.556  -0.807 -0.796
    IVSdiff           1.000          -0.711  -0.686 -0.683
    overall_measure  -0.711           1.000   0.733  0.756
    vnsim_0          -0.686           0.733   1.000  0.993
    LS               -0.683           0.756   0.993  1.000

### Finding all independent metrics with |r| < 0.80 threshold:
      1. SNR_dc_fix (BAM-Q signal-to-noise ratio (DC component))
      2. SNR_ac_fix (BAM-Q signal-to-noise ratio (AC component))
      3. ILDdiff (BAM-Q interaural level difference)
      4. IVSdiff (BAM-Q interaural vector strength difference)
      5. ITDdiff (BAM-Q interaural time difference)
      6. overall_measure (BAM-Q composite perceptual quality)
      7. LS (BINAQUAL localization similarity)

### Excluded 4 metrics due to high correlation (|r| >= 0.80):
      binQ, SNR_ac, vnsim_0, OPM_fix

### Excluding metrics based on BAM-Q / Binaqual paper content:
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
      metric             Min         Max       Range         Mean       Median
      <chr>            <dbl>       <dbl>       <dbl>        <dbl>        <dbl>
    1 ILDdiff         0      6517.       6517.       3850.        3488.       
    2 ITDdiff         0         0.000148    0.000148    0.0000894    0.0000930
    3 LS              0.0439    1           0.956       0.145        0.0498   
    4 overall_measure 0.236     0.723       0.487       0.431        0.382    
                SD
             <dbl>
    1 2192.       
    2    0.0000383
    3    0.285    
    4    0.126    

## 5. Euclidean Distance from Reference (Normalized)
       test             euclidean_distance
       <chr>                         <dbl>
     1 3OA-IAMF                       4.15
     2 2OA-TBE                        4.59
     3 42pIKO-Atmos                   4.77
     4 Auro3D                         4.99
     5 1OA-YT                         5.53
     6 42pIKO-Sony360RA               5.80
     7 42pIKO-Auro3D                  5.80
     8 42pIKO                         5.90
     9 Sony360RA                      6.05
    10 Atmos                          6.06

## 6. Format Rankings (1 = Best)
       test             rank_overall rank_LS rank_ILDdiff rank_ITDdiff avg_rank
       <chr>                   <dbl>   <dbl>        <dbl>        <dbl>    <dbl>
     1 7OA ref.                    1       1            1            1     1   
     2 3OA-IAMF                    4       4            2            2     3   
     3 2OA-TBE                     8       2            3            3     4   
     4 1OA-YT                      2       6            4           11     5.75
     5 42pIKO-Atmos                3      10            5            6     6   
     6 Auro3D                      5       7            7            5     6   
     7 42pIKO                      6       3           10            9     7   
     8 42pIKO-Sony360RA           11       9            6            4     7.5 
     9 Sony360RA                  10       5            9            8     8   
    10 42pIKO-Auro3D               9      11            8            7     8.75
    11 Atmos                       7       8           11           10     9   

## 7. Spatial Cue Asymmetry (ILD vs ITD)
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

## 8. Overall vs Localization Correlation
    Overall vs Localization Correlation:
    All formats (n = 11): r = 0.756, p = 0.0071
    Commercial only (n = 9): r = -0.113, p = 0.7725

## 9. PCA Summary
    PC1 variance explained: 44.2 %
    PC2 variance explained: 31.7 %
    PC1+PC2 cumulative variance: 75.9 %

### PCA Loadings:
                        PC1     PC2
    ILDdiff          0.6201  0.3429
    ITDdiff          0.5864 -0.2774
    overall_measure -0.1804 -0.8040
    LS              -0.4889  0.3988

### PCA Scores:
            PC1    PC2 test            
          <dbl>  <dbl> <chr>           
     1  0.526   -1.90  1OA-YT          
     2  0.891    0.585 42pIKO          
     3  1.41     0.326 Atmos           
     4 -0.361   -1.20  42pIKO-Atmos    
     5 -0.0744  -0.712 Auro3D          
     6  0.946    0.347 42pIKO-Auro3D   
     7 -1.94    -0.956 3OA-IAMF        
     8  1.18     0.727 Sony360RA       
     9  0.00762  1.41  42pIKO-Sony360RA
    10 -2.58     1.36  2OA-TBE         
