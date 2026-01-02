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
lines <- readLines("../data/benchmarking.txt")
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

cat("--- 5. Euclidean Distance from Reference (Normalized) ---\n")
ref_values <- df %>% filter(test == "7OA-MagLS") %>% select(all_of(c4m_vars))
test_formats <- data_analysis %>% filter(test != "7OA-MagLS") %>% select(test, all_of(c4m_vars))

all_data <- rbind(ref_values, test_formats[, c4m_vars])
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
rankings <- data_analysis %>%
  mutate(
    rank_overall = rank(-overall_measure, ties.method = "average"),
    rank_LS = rank(-LS, ties.method = "average"),
    rank_ILDdiff = rank(ILDdiff, ties.method = "average"),
    rank_ITDdiff = rank(ITDdiff, ties.method = "average")
  ) %>%
  mutate(avg_rank = (rank_overall + rank_LS + rank_ILDdiff + rank_ITDdiff) / 4) %>%
  select(test, rank_overall, rank_LS, rank_ILDdiff, rank_ITDdiff, avg_rank) %>%
  arrange(avg_rank) %>%
  mutate(test = remap_tests(test))

print(as.data.frame(rankings), digits = 2, row.names = FALSE)
cat("\n")

cat("--- 7. Spatial Cue Asymmetry (ILD vs ITD) ---\n")
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

cat("--- 8. Overall vs Localization Correlation ---\n")
cat("Overall vs Localization Correlation:\n")
cor_all <- cor.test(data_analysis$overall_measure, data_analysis$LS, method = "pearson")
cor_comm <- cor.test(commercial_formats$overall_measure, commercial_formats$LS, method = "pearson")

cat(sprintf("All formats (n = %d): r = %.3f, p = %.4f\n", nrow(data_analysis), as.numeric(cor_all$estimate), cor_all$p.value))
cat(sprintf("Commercial only (n = %d): r = %.3f, p = %.4f\n\n", nrow(commercial_formats), as.numeric(cor_comm$estimate), cor_comm$p.value))

cat("--- 9. PCA Summary ---\n")
pca_data <- data_analysis %>%
  filter(test != "7OA-MagLS") %>%
  select(all_of(c4m_vars))

pca_result <- prcomp(pca_data, scale. = TRUE, center = TRUE)
var_exp <- summary(pca_result)$importance[2, 1:2] * 100

cat("PC1 variance explained:", round(var_exp[1], 1), "%\n")
cat("PC2 variance explained:", round(var_exp[2], 1), "%\n")
cat("PC1+PC2 cumulative variance:", round(sum(var_exp), 1), "%\n\n")

cat("PCA Loadings:\n")
print(round(pca_result$rotation[, 1:2], 4))
cat("\n")

cat("PCA Scores:\n")
pca_scores <- as.data.frame(pca_result$x[, 1:2])
pca_scores$test <- data_analysis %>% filter(test != "7OA-MagLS") %>% pull(test) %>% remap_tests()
print(pca_scores, digits = 4, row.names = FALSE)

