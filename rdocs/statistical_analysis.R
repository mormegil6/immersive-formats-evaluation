#!/usr/bin/env Rscript
# Statistical Analysis - Immersive Audio Benchmarking
# Reads raw data and prints statistical analysis outputs

suppressPackageStartupMessages(library(tidyverse))

# Set tibble printing options to prevent wrapping/truncation
options(width = 10000)  # Very wide terminal width
options(tibble.width = Inf)  # Print all columns
options(tibble.print_max = Inf)  # Print all rows

# ========== Configuration ==========
reference_formats <- c("7OA-MagLS")
non_commercial_formats <- c("42pIKO-MagLS")
correlation_threshold <- 0.80

format_mapping <- list(
  "7OA-MagLS" = "7OA ref.",
  "42pIKO-MagLS" = "42pIKO",
  "Atmos-native" = "Atmos",
  "Auro3D-native" = "Auro3D",
  "Sony360RA-native" = "Sony360RA"
)

remap_tests <- function(test_vec) {
  sapply(test_vec, function(t) ifelse(t %in% names(format_mapping), format_mapping[[t]], t), 
         USE.NAMES = FALSE)
}

# ========== Data Import ==========
lines <- readLines("./data/benchmarking.txt")
data_list <- list()
current_comparison <- NULL
current_data <- list()

for(line in lines) {
  if(grepl("DeusExMachina_7OA-MagLS_binaural_N vs ", line)) {
    if(!is.null(current_comparison)) {
      data_list[[current_comparison]] <- current_data
    }
    current_comparison <- sub(".*vs DeusExMachina_(.+)_binaural.*", "\\1", line)
    current_data <- list()
  }
  
  if(grepl("\\w+:\\s*[-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?", line) &&
     !grepl("\\*\\*\\*", line)) {
    parts <- strsplit(trimws(line), ":\\s*")[[1]]
    if(length(parts) == 2) {
      metric_name <- trimws(parts[1])
      metric_value <- as.numeric(parts[2])
      current_data[[metric_name]] <- metric_value
    }
  }
}

if(!is.null(current_comparison)) {
  data_list[[current_comparison]] <- current_data
}

df <- bind_rows(lapply(names(data_list), function(test) {
  c(test = test, data_list[[test]])
}))

for(col in names(df)[-1]) {
  df[[col]] <- as.numeric(df[[col]])
}

# ========== Categorization ==========
data_all <- df %>%
  mutate(category = case_when(
    test %in% reference_formats ~ "Reference",
    test %in% non_commercial_formats ~ "Non-Commercial",
    TRUE ~ "Commercial"
  ))

data_analysis <- data_all %>% filter(category != "Experimental")
commercial_formats <- data_analysis %>% filter(category == "Commercial")

# ========== Output Results ==========
cat("\n========== IMMERSIVE AUDIO BENCHMARKING - STATISTICAL ANALYSIS ==========\n\n")

cat("--- 1. Dataset Overview ---\n")
cat("Total formats analyzed:", nrow(data_analysis), "\n")
cat("Reference formats:", paste(reference_formats, collapse=", "), "\n")
cat("Non-commercial formats:", paste(non_commercial_formats, collapse=", "), "\n")
cat("Commercial formats:", paste(commercial_formats$test, collapse=", "), "\n\n")

cat("--- 2. Raw Data ---\n")
print(as.data.frame(df), digits = 4, row.names = FALSE)
cat("\n")

cat("--- 3. Metric Selection and Redundancy Removal ---\n")
cat("Full correlation matrix (all available metrics):\n")
all_metrics <- setdiff(names(df), c("test"))

# Detect and exclude perfectly correlated metrics
# Prefer _fix versions over non-fix versions when both exist and are identical
corr_all <- cor(df[, all_metrics], method = "pearson", use = "complete.obs")
redundant_metrics <- c()

for(i in 1:(length(all_metrics)-1)) {
  if(all_metrics[i] %in% redundant_metrics) next
  for(j in (i+1):length(all_metrics)) {
    if(all_metrics[j] %in% redundant_metrics) next
    if(abs(corr_all[i, j]) > 0.999) {  # Perfect correlation (allowing for rounding)
      # Prefer _fix version
      if(grepl("_fix$", all_metrics[j]) && !grepl("_fix$", all_metrics[i])) {
        redundant_metrics <- c(redundant_metrics, all_metrics[i])
        cat(sprintf("  Excluding %s (r=%.3f with %s, keeping _fix version)\n", 
                    all_metrics[i], corr_all[i, j], all_metrics[j]))
      } else if(grepl("_fix$", all_metrics[i]) && !grepl("_fix$", all_metrics[j])) {
        redundant_metrics <- c(redundant_metrics, all_metrics[j])
        cat(sprintf("  Excluding %s (r=%.3f with %s, keeping _fix version)\n", 
                    all_metrics[j], corr_all[i, j], all_metrics[i]))
      } else {
        # If neither or both have _fix, exclude the second one
        redundant_metrics <- c(redundant_metrics, all_metrics[j])
        cat(sprintf("  Excluding %s (r=%.3f with %s, perfectly correlated)\n", 
                    all_metrics[j], corr_all[i, j], all_metrics[i]))
      }
    }
  }
}

if(length(redundant_metrics) > 0) {
  cat("\n")
}

all_metrics <- setdiff(all_metrics, redundant_metrics)
corr_all_metrics <- cor(df[, all_metrics], method = "pearson", use = "complete.obs")
print(round(corr_all_metrics, 3))
cat("\n")

# Selection: find ALL independent metrics with |r| < threshold
# add metrics one-by-one, checking independence from already-selected set

independent_metrics <- c()
excluded_by_correlation <- c()

# Sort metrics by average absolute correlation (less-correlated metrics first)
abs_corr <- abs(corr_all_metrics)
diag(abs_corr) <- 0
avg_corr <- rowMeans(abs_corr)
metrics_ordered <- names(sort(avg_corr))

for(metric in metrics_ordered) {
  if(length(independent_metrics) == 0) {
    independent_metrics <- metric
  } else {
    max_corr_with_selected <- max(abs(corr_all_metrics[metric, independent_metrics]))
    if(max_corr_with_selected < correlation_threshold) {
      independent_metrics <- c(independent_metrics, metric)
    } else {
      excluded_by_correlation <- c(excluded_by_correlation, metric)
    }
  }
}

cat(sprintf("Independent metrics meeting |r| < %.2f criterion:\n", correlation_threshold))
for(i in seq_along(independent_metrics)) {
  m <- independent_metrics[i]
  desc <- switch(m,
    "overall_measure" = "BAM-Q composite perceptual quality",
    "LS" = "BINAQUAL localization similarity",
    "ILDdiff" = "BAM-Q interaural level difference",
    "ITDdiff" = "BAM-Q interaural time difference",
    "SNR_dc_fix" = "BAM-Q signal-to-noise ratio (DC component)",
    "SNR_ac_fix" = "BAM-Q signal-to-noise ratio (AC component)",
    "IVSdiff" = "BAM-Q interaural vector strength difference",
    "model-derived metric"
  )
  cat(sprintf("  %d. %s (%s)\n", i, m, desc))
}

if(length(excluded_by_correlation) > 0) {
  cat(sprintf("\nExcluded %d metrics due to high correlation (|r| >= %.2f):\n", 
              length(excluded_by_correlation), correlation_threshold))
  cat(sprintf("  %s\n", paste(excluded_by_correlation, collapse=", ")))
}
cat("\n")

# Conceptual rationale: keep perceptual metrics
cat("Excluding metrics based on BAM-Q paper:\n")
metrics_to_exclude <- c("SNR_dc_fix", "SNR_ac_fix", "IVSdiff")
cat(sprintf("  %s\n", paste(metrics_to_exclude, collapse=", ")))
cat("Rationale:\n")
cat("  - SNR_dc_fix, SNR_ac_fix: Signal-to-noise ratios quantifying signal power\n")
cat("    preservation rather than perceptual quality degradation (Fleßner et al., 2019).\n")
cat("  - IVSdiff: Binaural coherence measure conceptually redundant with selected\n")
cat("    ILDdiff/ITDdiff spatial cue metrics.\n")
cat("  - The 4 selected metrics provide complete perceptual coverage: overall quality\n")
cat("    (overall_measure), localization (LS), amplitude cues (ILDdiff), temporal cues (ITDdiff).\n")
cat("\n")
c4m_vars <- setdiff(independent_metrics, metrics_to_exclude)

# Two-tier analysis: primary composites vs diagnostic sub-metrics
primary_vars <- c("overall_measure", "LS")
diagnostic_vars <- setdiff(c4m_vars, primary_vars)

cat(sprintf("Selected %d metrics for analysis:\n", length(c4m_vars)))
for(i in seq_along(c4m_vars)) {
  m <- c4m_vars[i]
  desc <- switch(m,
    "overall_measure" = "BAM-Q composite perceptual quality",
    "LS" = "BINAQUAL localization similarity",
    "ILDdiff" = "BAM-Q interaural level difference",
    "ITDdiff" = "BAM-Q interaural time difference",
    "SNR_dc_fix" = "BAM-Q signal-to-noise ratio (DC component)",
    "SNR_ac_fix" = "BAM-Q signal-to-noise ratio (AC component)",
    "IVSdiff" = "BAM-Q interaural vector strength difference",
    "model-derived metric"
  )
  cat(sprintf("  %d. %s (%s)\n", i, m, desc))
}

cat("\nTwo-tier analysis structure:\n")
cat("  (a) PRIMARY: overall_measure + LS (composite perceptual metrics)\n")
cat("      Used for Euclidean distance and rankings to avoid double-counting.\n")
cat("      Rationale: overall_measure (BAM-Q) already incorporates ILDdiff/ITDdiff\n")
cat("      internally; including them separately inflates binaural cue weight.\n")
cat("  (b) DIAGNOSTIC: ILDdiff + ITDdiff (explanatory sub-metrics)\n")
cat("      Reported separately for spatial cue analysis.\n\n")

cat("Correlation validation for selected metric set:\n")
c4m_corr <- cor(data_analysis[, c4m_vars], method = "pearson")
print(round(c4m_corr, 3))
cat("\n")

cat("Key pairwise correlations:\n")
max_abs_corr <- max(abs(c4m_corr[c4m_corr != 1]))
corr_pairs <- which(abs(c4m_corr) == max_abs_corr & upper.tri(c4m_corr), arr.ind = TRUE)
if(nrow(corr_pairs) > 0) {
  for(i in 1:min(3, nrow(corr_pairs))) {
    m1 <- rownames(c4m_corr)[corr_pairs[i, 1]]
    m2 <- colnames(c4m_corr)[corr_pairs[i, 2]]
    cat(sprintf("  %s <-> %s: r = %.3f\n", m1, m2, c4m_corr[m1, m2]))
  }
}
cat(sprintf("  Maximum |r| in %d-metric set: %.3f\n", length(c4m_vars), max_abs_corr))
cat(sprintf("All pairwise correlations |r| < %.2f confirmed.\n\n", correlation_threshold))

cat(sprintf("--- 4. Summary Statistics (%d Metrics) ---\n", length(c4m_vars)))
summary_stats <- data_analysis %>%
  select(all_of(c4m_vars)) %>%
  pivot_longer(cols = everything(), names_to = "metric", values_to = "value") %>%
  group_by(metric) %>%
  summarise(
    Min = min(value, na.rm = TRUE),
    Max = max(value, na.rm = TRUE),
    Range = Max - Min,
    Mean = mean(value, na.rm = TRUE),
    Median = median(value, na.rm = TRUE),
    SD = sd(value, na.rm = TRUE),
    .groups = "drop"
  )
print(as.data.frame(summary_stats), digits = 4, row.names = FALSE)
cat("\n")

cat("--- 5. Euclidean Distance from Reference (Primary Metrics Only) ---\n")
cat("Using only composite perceptual metrics (overall_measure, LS) to avoid\n")
cat("double-counting ILDdiff/ITDdiff which are internal to BAM-Q overall_measure.\n\n")
ref_values <- df %>% filter(test == "7OA-MagLS") %>% select(all_of(primary_vars))
test_formats <- data_analysis %>% filter(test != "7OA-MagLS") %>% select(test, all_of(primary_vars))

all_data <- rbind(ref_values, test_formats[, primary_vars])
metrics_normalized <- scale(all_data)
ref_normalized <- metrics_normalized[1, ]
test_normalized <- metrics_normalized[-1, ]

euclidean_dist <- apply(test_normalized, 1, function(row) sqrt(sum((row - ref_normalized)^2)))

deviation_data <- data.frame(
  test = test_formats$test,
  euclidean_distance = euclidean_dist
) %>%
  mutate(test = remap_tests(test)) %>%
  arrange(euclidean_distance) %>%
  as_tibble()

print(as.data.frame(deviation_data), digits = 4, row.names = FALSE)
cat("\n")

cat("--- 6. Format Rankings (1 = Best) ---\n")
cat("Primary ranking uses only composite metrics (overall_measure, LS).\n")
cat("Old 4-metric ranking shown for comparison.\n\n")

# Old 4-metric rankings (for comparison)
rankings_old <- data_analysis %>%
  mutate(
    rank_overall = rank(-overall_measure, ties.method = "average"),
    rank_LS = rank(-LS, ties.method = "average"),
    rank_ILDdiff = rank(ILDdiff, ties.method = "average"),
    rank_ITDdiff = rank(ITDdiff, ties.method = "average")
  ) %>%
  mutate(avg_rank_4m = (rank_overall + rank_LS + rank_ILDdiff + rank_ITDdiff) / 4) %>%
  select(test, avg_rank_4m) %>%
  mutate(test = remap_tests(test))

# New 2-metric rankings (primary)
rankings_new <- data_analysis %>%
  mutate(
    rank_overall = rank(-overall_measure, ties.method = "average"),
    rank_LS = rank(-LS, ties.method = "average")
  ) %>%
  mutate(avg_rank_2m = (rank_overall + rank_LS) / 2) %>%
  select(test, rank_overall, rank_LS, avg_rank_2m) %>%
  mutate(test = remap_tests(test))

# Side-by-side comparison
rankings_comparison <- rankings_new %>%
  left_join(rankings_old, by = "test") %>%
  mutate(rank_change = avg_rank_4m - avg_rank_2m) %>%
  arrange(avg_rank_2m)

print(as.data.frame(rankings_comparison), digits = 2, row.names = FALSE)
cat("\n")

cat("--- 7. Spatial Cue Asymmetry (ILD vs ITD) [DIAGNOSTIC] ---\n")
cat("Note: ILDdiff and ITDdiff are shown as diagnostic/explanatory sub-metrics.\n")
cat("They are NOT included in the primary quality ranking to avoid double-counting\n")
cat("with overall_measure (BAM-Q composite), which incorporates them internally.\n\n")
data_no_ref <- data_analysis %>% filter(test != "7OA-MagLS")

ILD_stats <- summary_stats %>% filter(metric == "ILDdiff")
ITD_stats <- summary_stats %>% filter(metric == "ITDdiff")

if(nrow(ILD_stats) > 0 && nrow(ITD_stats) > 0) {
  ILD_CV <- ILD_stats$SD[1] / ILD_stats$Mean[1]
  ITD_CV <- ITD_stats$SD[1] / ITD_stats$Mean[1]
  CV_ratio <- ILD_CV / ITD_CV
  ILD_fold <- ILD_stats$Max[1] / min(data_no_ref$ILDdiff[data_no_ref$ILDdiff > 0])
  ITD_fold <- ITD_stats$Max[1] / min(data_no_ref$ITDdiff[data_no_ref$ITDdiff > 0])
  Range_ratio <- ILD_stats$Range[1] / ITD_stats$Range[1]
  SD_ratio <- ILD_stats$SD[1] / ITD_stats$SD[1]

  spatial_asymmetry <- data.frame(
    Metric = c("ILD_CV", "ITD_CV", "CV_Ratio", "ILD_Range", "ITD_Range", 
               "Range_Ratio", "ILD_SD", "ITD_SD", "SD_Ratio", "ILD_Fold", "ITD_Fold"),
    Value = c(ILD_CV, ITD_CV, CV_ratio, ILD_stats$Range[1], ITD_stats$Range[1], 
              Range_ratio, ILD_stats$SD[1], ITD_stats$SD[1], SD_ratio, ILD_fold, ITD_fold)
  )
  
  print(spatial_asymmetry, digits = 4)
}
cat("\n")

cat("--- 8. Overall vs Localization Correlation (Descriptive) ---\n")
cat("Pearson r reported as descriptive statistic only (exhaustive dataset, n=11).\n")
cat("No p-values: observations are non-independent and not sampled from a population.\n\n")

# Define subsets
ambisonics_pattern <- "OA|IAMF|TBE|YT"
data_no_ref <- data_analysis %>% filter(test != "7OA-MagLS")
ambisonics_formats <- data_no_ref %>% filter(grepl(ambisonics_pattern, test))
channel_obj_formats <- data_no_ref %>% filter(!grepl(ambisonics_pattern, test))

cor_all_inc_ref <- cor(data_analysis$overall_measure, data_analysis$LS, method = "pearson")
cor_all_exc_ref <- cor(data_no_ref$overall_measure, data_no_ref$LS, method = "pearson")
cor_ambi <- cor(ambisonics_formats$overall_measure, ambisonics_formats$LS, method = "pearson")
cor_chan <- cor(channel_obj_formats$overall_measure, channel_obj_formats$LS, method = "pearson")

cat(sprintf("(a) All formats incl. reference (n = %d): r = %.3f\n", nrow(data_analysis), cor_all_inc_ref))
cat(sprintf("(b) All formats excl. reference (n = %d): r = %.3f\n", nrow(data_no_ref), cor_all_exc_ref))
cat(sprintf("(c) Ambisonics-based excl. reference (n = %d): r = %.3f\n", nrow(ambisonics_formats), cor_ambi))
cat(sprintf("    Formats: %s\n", paste(remap_tests(ambisonics_formats$test), collapse = ", ")))
cat(sprintf("(d) Channel/object-based excl. reference (n = %d): r = %.3f\n", nrow(channel_obj_formats), cor_chan))
cat(sprintf("    Formats: %s\n", paste(remap_tests(channel_obj_formats$test), collapse = ", ")))
cat("\n")

cat("--- 9. BINAQUAL LS Metric Behavior ---\n")
cat("BINAQUAL was validated for within-order codec comparison (e.g., compressed vs\n")
cat("uncompressed FOA). Our cross-format paradigm (all formats vs 7OA reference)\n")
cat("depresses all vnsim values, and the LS = vnsim_0 * vnsim_1 product compounds\n")
cat("this compression. This section documents the issue.\n\n")

# Raw vnsim and LS values
ls_data <- data_analysis %>%
  select(test, vnsim_0, vnsim_1, LS) %>%
  mutate(
    LS_check = vnsim_0 * vnsim_1,
    LS_mean = (vnsim_0 + vnsim_1) / 2,
    test = remap_tests(test)
  )

cat("9a. Raw localization similarity components:\n")
print(as.data.frame(ls_data %>% select(test, vnsim_0, vnsim_1, LS, LS_check, LS_mean)),
      digits = 4, row.names = FALSE)
cat("\n")

# Verify LS = vnsim_0 * vnsim_1
max_diff <- max(abs(ls_data$LS - ls_data$LS_check))
cat(sprintf("9b. Formula verification: LS = vnsim_0 * vnsim_1\n"))
cat(sprintf("    Max |LS - vnsim_0*vnsim_1| = %.2e %s\n\n",
            max_diff, ifelse(max_diff < 1e-6, "(confirmed, floating-point precision)", "(MISMATCH)")))

# Rankings under each formulation
ls_no_ref <- ls_data %>% filter(test != "7OA ref.")
cat("9c. Rankings comparison (product vs mean, excluding reference):\n")
ls_rankings <- ls_no_ref %>%
  mutate(
    rank_LS_product = rank(-LS, ties.method = "average"),
    rank_LS_mean = rank(-LS_mean, ties.method = "average")
  ) %>%
  select(test, LS, rank_LS_product, LS_mean, rank_LS_mean) %>%
  arrange(rank_LS_product)
print(as.data.frame(ls_rankings), digits = 4, row.names = FALSE)
cat("\n")

# Correlation with overall_measure for both LS variants
cat("9d. Correlation of overall_measure with LS variants (descriptive r):\n")
cor_prod_inc <- cor(data_analysis$overall_measure, data_analysis$LS, method = "pearson")
cor_mean_inc <- cor(data_analysis$overall_measure, ls_data$LS_mean, method = "pearson")

data_no_ref_ls <- ls_data %>% filter(test != "7OA ref.")
cor_prod_exc <- cor(data_no_ref$overall_measure, data_no_ref_ls$LS, method = "pearson")
cor_mean_exc <- cor(data_no_ref$overall_measure, data_no_ref_ls$LS_mean, method = "pearson")

cat(sprintf("    Incl. reference:  LS_product r = %.3f,  LS_mean r = %.3f\n", cor_prod_inc, cor_mean_inc))
cat(sprintf("    Excl. reference:  LS_product r = %.3f,  LS_mean r = %.3f\n\n", cor_prod_exc, cor_mean_exc))

# Dynamic range comparison
prod_range <- diff(range(ls_no_ref$LS))
mean_range <- diff(range(ls_no_ref$LS_mean))
cat("9e. Dynamic range (non-reference formats):\n")
cat(sprintf("    LS_product: min = %.4f, max = %.4f, range = %.4f\n",
            min(ls_no_ref$LS), max(ls_no_ref$LS), prod_range))
cat(sprintf("    LS_mean:    min = %.4f, max = %.4f, range = %.4f\n",
            min(ls_no_ref$LS_mean), max(ls_no_ref$LS_mean), mean_range))
cat(sprintf("    Ratio (mean/product range): %.1fx wider dynamic range with mean formulation\n",
            mean_range / prod_range))
cat("\n")

cat("--- 10. Within-Category Metric Discrimination ---\n")
cat("CV (SD/mean) per metric within each format family. CV > 0.15 = good\n")
cat("discrimination, CV < 0.15 = poor discrimination within that group.\n\n")

disc_metrics <- c("overall_measure", "LS", "ILDdiff", "ITDdiff")

# Categorize: Ambisonics (pure, no 42pIKO) vs channel/object (everything else)
ambi_pure <- data_no_ref %>% filter(grepl("OA|IAMF|TBE", test) & !grepl("42pIKO", test))
chan_obj <- data_no_ref %>% filter(!test %in% ambi_pure$test)

cat(sprintf("Ambisonics-based (n = %d): %s\n",
            nrow(ambi_pure), paste(remap_tests(ambi_pure$test), collapse = ", ")))
cat(sprintf("Channel/object-based (n = %d): %s\n\n",
            nrow(chan_obj), paste(remap_tests(chan_obj$test), collapse = ", ")))

# Compute stats per group
compute_disc <- function(data, metrics) {
  data.frame(
    metric = metrics,
    min = sapply(metrics, function(m) min(data[[m]])),
    max = sapply(metrics, function(m) max(data[[m]])),
    mean = sapply(metrics, function(m) mean(data[[m]])),
    SD = sapply(metrics, function(m) sd(data[[m]])),
    CV = sapply(metrics, function(m) sd(data[[m]]) / mean(data[[m]])),
    row.names = NULL
  )
}

ambi_disc <- compute_disc(ambi_pure, disc_metrics)
chan_disc <- compute_disc(chan_obj, disc_metrics)

cat("10a. Ambisonics-based formats:\n")
print(ambi_disc, digits = 4, row.names = FALSE)
cat(sprintf("  Discriminating (CV > 0.15): %s\n",
            paste(ambi_disc$metric[ambi_disc$CV > 0.15], collapse = ", ")))
cat(sprintf("  Poor discrimination (CV <= 0.15): %s\n\n",
            paste(ambi_disc$metric[ambi_disc$CV <= 0.15], collapse = ", ")))

cat("10b. Channel/object-based formats:\n")
print(chan_disc, digits = 4, row.names = FALSE)
cat(sprintf("  Discriminating (CV > 0.15): %s\n",
            paste(chan_disc$metric[chan_disc$CV > 0.15], collapse = ", ")))
cat(sprintf("  Poor discrimination (CV <= 0.15): %s\n\n",
            paste(chan_disc$metric[chan_disc$CV <= 0.15], collapse = ", ")))

cat("10c. CV comparison (Ambisonics vs Channel/Object):\n")
cv_comparison <- data.frame(
  metric = disc_metrics,
  CV_ambisonics = ambi_disc$CV,
  CV_channel_obj = chan_disc$CV,
  ratio = ambi_disc$CV / chan_disc$CV,
  better_for = ifelse(ambi_disc$CV > chan_disc$CV, "Ambisonics", "Channel/Obj")
)
print(cv_comparison, digits = 3, row.names = FALSE)
cat("\n")

cat("--- 11. Quality Space Data (overall_measure vs LS) ---\n")
cat("Format-level data for 2D scatter plot (overall perceptual quality vs localization).\n\n")
scatter_data <- data_analysis %>%
  select(test, overall_measure, LS) %>%
  mutate(test = remap_tests(test)) %>%
  arrange(desc(overall_measure))
print(as.data.frame(scatter_data), digits = 4, row.names = FALSE)

