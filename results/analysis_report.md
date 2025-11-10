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
              metric    Min       Max     Range      Mean    Median        SD
             ILDdiff 0.0000 6.517e+03 6.517e+03 3.850e+03 3.488e+03 2.192e+03
             ITDdiff 0.0000 1.479e-04 1.479e-04 8.942e-05 9.297e-05 3.829e-05
                  LS 0.0439 1.000e+00 9.561e-01 1.454e-01 4.985e-02 2.851e-01
     overall_measure 0.2358 7.226e-01 4.868e-01 4.312e-01 3.822e-01 1.258e-01

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
