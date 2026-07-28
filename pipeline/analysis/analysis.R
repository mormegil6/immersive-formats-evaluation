## analysis.R -- statistical analysis for the Applied Acoustics revision.
##
##   Rscript analysis.R [data_dir] [fig_dir] [values_tex]
##
## Reads  data/revision/metrics_long.csv           (scored pairs)
##        data/revision/stimulus_conditioning.csv  (corrections applied)
##        data/revision/metrics_long_noalign.csv   (optional control arm)
## Writes figures, per-figure data tables, and values.tex.
##
## Base R only -- see common.R.

args <- commandArgs(trailingOnly = TRUE)
## Resolve this script's own directory so that common.R is found regardless of
## the working directory the script is invoked from. sys.frame()$ofile is NULL
## under Rscript, so --file= is consulted first.
HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f[1]))
  else tryCatch(dirname(normalizePath(sys.frame(1)$ofile)), error = function(e) ".")
})
DATA_DIR  <- if (length(args) >= 1) args[1] else "../../data/revision"
FIG_DIR   <- if (length(args) >= 2) args[2] else "../../plots/revision"
VALUES    <- if (length(args) >= 3) args[3] else
  "../../__Applied Acoustics 2026 - Benchmarking Immersive Formats/values.tex"

source(file.path(HERE, "common.R"))
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

d <- load_metrics(file.path(DATA_DIR, "metrics_long.csv"))

## The conditioning record must describe the same material that was scored, so
## prefer the excerpt-specific manifest when one exists.
cond_file <- Filter(function(f) file.exists(file.path(DATA_DIR, f)),
                    c("conditioning_60s.csv", "stimulus_conditioning.csv"))
if (!length(cond_file)) stop("no stimulus conditioning manifest found in ", DATA_DIR)
cond <- utils::read.csv(file.path(DATA_DIR, cond_file[1]), stringsAsFactors = FALSE)
message("conditioning manifest: ", cond_file[1])

noalign_path <- file.path(DATA_DIR, "metrics_long_noalign.csv")
has_noalign  <- file.exists(noalign_path)
if (has_noalign) dna <- load_metrics(noalign_path)

items    <- levels(droplevels(d$item))
n_items  <- length(items)
P        <- primary(d)                       # 7OA anchor, tests only
variants <- levels(droplevels(P$variant))

cat("\n=== loaded ===\n")
cat("items    :", paste(items, collapse = ", "), "\n")
cat("anchors  :", paste(unique(d$anchor), collapse = ", "), "\n")
cat("variants :", length(variants), "\n")
cat("rows     :", nrow(d), "\n")
cat("no-align control arm:", has_noalign, "\n")

put_value("nItems", n_items, 0)
put_value("nFormats", length(variants), 0)
put_value("nPairs", nrow(d), 0)


## ===========================================================================
## 1. Stimulus conditioning -- what had to be corrected before scoring
## ===========================================================================
cat("\n=== 1. stimulus conditioning ===\n")

cond$abs_lag <- abs(cond$lag_samples)
cond$abs_ms  <- abs(cond$lag_ms)
nz <- cond[cond$abs_lag > 0 & cond$is_reference == 0, ]

cat(sprintf("variants with non-zero transport latency: %d of %d\n",
            nrow(nz), sum(cond$is_reference == 0)))
cat(sprintf("latency range: %.2f to %.1f ms (median %.2f ms)\n",
            min(nz$abs_ms), max(nz$abs_ms), median(nz$abs_ms)))
cat(sprintf("polarity inversions: %d\n", sum(cond$polarity == -1)))
cat(sprintf("loudness gain applied: %.1f to %+.1f dB\n",
            min(cond$gain_db), max(cond$gain_db)))
cat(sprintf("residual lag after correction: max |%d| samples\n",
            max(abs(cond$residual_lag_samples))))

put_value("maxLatencyMs", max(nz$abs_ms), 0)
put_value("medLatencyMs", median(nz$abs_ms), 2)
put_value("nLatencyAffected", nrow(nz), 0)
put_value("nPolarityInverted", sum(cond$polarity == -1), 0)
put_value("maxLoudnessSpread", max(cond$lufs_before) - min(cond$lufs_before), 1)
put_value("maxResidualLag", max(abs(cond$residual_lag_samples)), 0)

write_figure_data(cond[, c("item", "variant", "lag_samples", "lag_ms", "polarity",
                           "gcc_corr", "gcc_peak_ratio", "residual_lag_samples",
                           "lufs_before", "gain_db", "true_peak_dbtp_after")],
                  file.path(FIG_DIR, "Data_00_StimulusConditioning.csv"))


## ===========================================================================
## 2. Latency sensitivity of the two models  (control arm)
## ===========================================================================
if (has_noalign) {
  cat("\n=== 2. latency sensitivity (aligned vs not) ===\n")
  A <- primary(d);   B <- primary(dna)
  key <- function(x) paste(x$item, x$variant, sep = "|")
  lat <- merge(data.frame(k = key(A), item = A$item, variant = A$variant,
                        LS_a = A$LS, ov_a = A$overall_measure,
                        itd_a = A$ITDdiff_us, ild_a = A$ILDdiff_dB),
             data.frame(k = key(B), LS_u = B$LS, ov_u = B$overall_measure,
                        itd_u = B$ITDdiff_us, ild_u = B$ILDdiff_dB),
             by = "k")
  lat <- merge(lat, cond[cond$is_reference == 0,
                     c("item", "variant", "lag_samples", "lag_ms")],
             by = c("item", "variant"))
  lat$abs_ms   <- abs(lat$lag_ms)
  lat$LS_ratio <- lat$LS_a / lat$LS_u
  lat$ov_ratio <- lat$ov_a / lat$ov_u

  cat(sprintf("BINAQUAL LS   : median change %+.1f%% (range %+.1f%% to %+.1f%%)\n",
              100 * (median(lat$LS_ratio) - 1),
              100 * (min(lat$LS_ratio) - 1), 100 * (max(lat$LS_ratio) - 1)))
  cat(sprintf("BAM-Q overall : median change %+.1f%% (range %+.1f%% to %+.1f%%)\n",
              100 * (median(lat$ov_ratio) - 1),
              100 * (min(lat$ov_ratio) - 1), 100 * (max(lat$ov_ratio) - 1)))

  ## Does the uncorrected LS simply track how much latency the renderer added?
  rho_lat <- descr_cor(lat$abs_ms, lat$LS_u, method = "spearman")
  rho_cor <- descr_cor(lat$abs_ms, lat$LS_a, method = "spearman")
  cat(sprintf("Spearman rho(|latency|, LS): uncorrected %+.3f -> corrected %+.3f\n",
              rho_lat, rho_cor))

  ## Rank agreement between the corrected and uncorrected orderings.
  tau <- sapply(split(lat, lat$item, drop = TRUE), function(x)
    stats::cor(x$LS_a, x$LS_u, method = "kendall"))
  cat("Kendall tau (corrected vs uncorrected LS ranking) per item:\n")
  print(round(tau, 3))

  put_value("LSchangeMedian", median(lat$LS_ratio) - 1, percent = TRUE)
  put_value("LSchangeMax", max(lat$LS_ratio) - 1, percent = TRUE)
  put_value("OVchangeMedian", abs(median(lat$ov_ratio) - 1), percent = TRUE)
  put_value("OVchangeMax", max(abs(lat$ov_ratio - 1)), percent = TRUE)
  put_value("rhoLatencyLSuncorr", rho_lat, 2)
  put_value("rhoLatencyLScorr", rho_cor, 2)
  put_value("tauAlignMin", min(tau), 2)

  ## How far apart do the near-zero-latency variants sit from the rest before
  ## correction?  This is the quantity that makes an unaligned comparison
  ## actively misleading rather than merely noisy.
  zero <- lat$abs_ms < 0.05
  put_value("nZeroLatency", sum(zero) / n_items, 0)
  put_value("LSunalignZero",  mean(lat$LS_u[zero]),  2)
  put_value("LSunalignOther", mean(lat$LS_u[!zero]), 3)
  put_value("LSunalignRatio", mean(lat$LS_u[zero]) / mean(lat$LS_u[!zero]), 1)
  put_value("LSalignZero",  mean(lat$LS_a[zero]),  2)
  put_value("LSalignOther", mean(lat$LS_a[!zero]), 3)

  write_figure_data(lat, file.path(FIG_DIR, "Data_01_LatencySensitivity.csv"))
}


## ===========================================================================
## 3. Format performance under the primary (7OA) anchor
## ===========================================================================
cat("\n=== 3. format performance, 7OA anchor ===\n")

agg <- function(metric) {
  a <- aggregate(P[[metric]], by = list(variant = P$variant), FUN = mean)
  s <- aggregate(P[[metric]], by = list(variant = P$variant), FUN = sd)
  data.frame(variant = a$variant, mean = a$x, sd = s$x)
}
summ <- Reduce(function(x, y) merge(x, y, by = "variant"),
               lapply(c(PRIMARY_METRICS, "ILDdiff_dB", "ITDdiff_us", "binQ"),
                      function(mt) {
                        z <- agg(mt); names(z)[-1] <- paste0(mt, c("_mean", "_sd")); z
                      }))
summ <- summ[order(-summ$overall_measure_mean), ]
print(summ, row.names = FALSE, digits = 4)
write_figure_data(summ, file.path(FIG_DIR, "Data_02_SummaryStats.csv"))

## Per-item ranks and mean rank across items.
ranks <- list()
for (mt in PRIMARY_METRICS) {
  r <- rank_within_item(P, mt, higher_better = TRUE)
  w <- to_matrix(r, "rank", "item")
  ranks[[mt]] <- w
}
mean_rank <- (colMeans(ranks$overall_measure) + colMeans(ranks$LS)) / 2
ord <- order(mean_rank)
cat("\nmean rank across items and both primary metrics (1 = best):\n")
print(round(sort(mean_rank), 2))

rank_tab <- data.frame(
  variant       = names(mean_rank),
  rank_overall  = round(colMeans(ranks$overall_measure), 2),
  rank_LS       = round(colMeans(ranks$LS), 2),
  mean_rank     = round(mean_rank, 2))[ord, ]
write_figure_data(rank_tab, file.path(FIG_DIR, "Data_03_FormatRankings.csv"))

## Emit the complete table so the manuscript never contains hand-typed ranks.
## The whole environment is generated rather than a fragment spliced inside
## tabular: a fragment whose final row ends in \\ leaves an empty row before
## \bottomrule, which LaTeX rejects with "Misplaced \noalign".
tex_label <- c("5OA"="5OA", "3OA-IAMF"="3OA-IAMF", "2OA-TBE"="2OA-TBE",
               "1OA-YT"="1OA-YT", "42pIKO"="42pIKO", "Atmos"="Dolby Atmos",
               "Auro3D"="Auro-3D", "Sony360RA"="Sony 360RA",
               "42pIKO-Atmos"="42pIKO$\\to$Atmos",
               "42pIKO-Auro3D"="42pIKO$\\to$Auro-3D",
               "42pIKO-Sony360RA"="42pIKO$\\to$Sony 360RA")
rows <- sprintf("        %-24s & %5.2f & %5.2f & %5.2f",
                vapply(as.character(rank_tab$variant), function(v) tex_label[[v]], ""),
                rank_tab$rank_overall, rank_tab$rank_LS, rank_tab$mean_rank)
writeLines(c(
  "%% Generated by pipeline/analysis/analysis.R -- do not edit by hand.",
  "\\begin{table}[!t]",
  "    \\caption{Format rankings under the 7OA anchor, averaged over the content",
  "             items (1~=~best). Mean rank averages the two primary metrics.}",
  "    \\label{tab:rankings}",
  "    \\centering",
  "    \\small",
  "    \\begin{tabular}{lccc}",
  "        \\toprule",
  "        \\textbf{Format} & \\textbf{Rank (overall)} & \\textbf{Rank (LS)} & \\textbf{Mean rank} \\\\",
  "        \\midrule",
  paste0(paste0(rows, " \\\\"), collapse = "\n"),
  "        \\bottomrule",
  "    \\end{tabular}",
  "\\end{table}"),
  file.path(dirname(VALUES), "table_rankings.tex"))
message("table -> table_rankings.tex")

put_value("bestFormat", as.character(rank_tab$variant[1]))
put_value("worstFormat", as.character(rank_tab$variant[nrow(rank_tab)]))


## ===========================================================================
## 4. Generalisability across content  (Reviewers 1, 2, 3)
## ===========================================================================
cat("\n=== 4. cross-content concordance ===\n")

concord <- data.frame()
for (mt in c(PRIMARY_METRICS, "ILDdiff", "ITDdiff")) {
  hb <- mt %in% PRIMARY_METRICS
  mm <- to_matrix(P, mt, "item")
  if (!hb) mm <- -mm                       # so that rank 1 is always "best"
  kw <- kendall_w(mm)
  fr <- tryCatch(stats::friedman.test(mm), error = function(e) NULL)
  pp <- kendall_w_perm(mm)                 # permutation p, see common.R
  concord <- rbind(concord, data.frame(
    metric = mt, W = kw$W, chi2 = kw$chi2, df = kw$df, p = kw$p, p_perm = pp,
    friedman_p = if (is.null(fr)) NA_real_ else unname(fr$p.value)))
  cat(sprintf("%-16s Kendall W = %.3f  chi2(%d) = %.2f  p_chisq = %.4f  p_perm = %.4f\n",
              mt, kw$W, kw$df, kw$chi2, kw$p, pp))
}
write_figure_data(concord, file.path(FIG_DIR, "Data_04_Concordance.csv"))

for (mt in c("overall_measure","LS","ILDdiff","ITDdiff")) {
  sfx <- c(overall_measure="OV", LS="LS", ILDdiff="ILD", ITDdiff="ITD")[[mt]]
  put_value(paste0("W", sfx, "Items"),    concord$W[concord$metric == mt], 2)
  put_value(paste0("chi", sfx, "Items"),  concord$chi2[concord$metric == mt], 1)
  put_value(paste0("pval", sfx, "Items"), concord$p[concord$metric == mt], 3)
  ## Emitted as a complete comparison ("= 0.0015" / "< 0.00001") because a
  ## Monte-Carlo p-value cannot be reported as an exact zero.
  put_value(paste0("pperm", sfx, "Items"),
            fmt_perm_p(concord$p_perm[concord$metric == mt]))
}
put_value("pOverallItems", concord$p[concord$metric == "overall_measure"], 4)
put_value("pLSItems",      concord$p[concord$metric == "LS"], 4)
put_value("kendallPermB", format(KENDALL_PERM_B, big.mark = ","))

## Which formats are content-stable and which are not?
rng <- do.call(rbind, lapply(PRIMARY_METRICS, function(mt) {
  mm <- to_matrix(P, mt, "item")
  data.frame(metric = mt, variant = colnames(mm),
             range = apply(mm, 2, function(x) diff(range(x))),
             cv = apply(mm, 2, cv))
}))
write_figure_data(rng, file.path(FIG_DIR, "Data_05_ContentVariability.csv"))


## ===========================================================================
## 5. Metric independence
## ===========================================================================
cat("\n=== 5. BAM-Q vs BINAQUAL agreement ===\n")

withref <- d[d$anchor == "7OA", ]
r_all  <- descr_cor(withref$overall_measure, withref$LS)
r_excl <- descr_cor(P$overall_measure, P$LS)
r_amb  <- descr_cor(P$overall_measure[P$family == "Ambisonics"],
                    P$LS[P$family == "Ambisonics"])
r_chan <- descr_cor(P$overall_measure[P$family == "Channel/Object"],
                    P$LS[P$family == "Channel/Object"])
cat(sprintf("including reference : r = %+.3f (n = %d)\n", r_all, nrow(withref)))
cat(sprintf("excluding reference : r = %+.3f (n = %d)\n", r_excl, nrow(P)))
cat(sprintf("Ambisonics only     : r = %+.3f\n", r_amb))
cat(sprintf("Channel/Object only : r = %+.3f\n", r_chan))

## Within-item correlations, so that the pooled value is not an artefact of
## between-item level differences.
r_item <- sapply(split(P, P$item, drop = TRUE),
                 function(x) descr_cor(x$overall_measure, x$LS))
cat("within-item r:\n"); print(round(r_item, 3))

put_value("corrAllRef", r_all, 2)
put_value("corrExclRef", r_excl, 2)
put_value("corrAmb", r_amb, 2)
put_value("corrChan", r_chan, 2)
put_value("corrWithinItemMin", min(r_item), 2)
put_value("corrWithinItemMax", max(r_item), 2)

write_figure_data(
  data.frame(subset = c("incl. reference", "excl. reference",
                        "Ambisonics", "Channel/Object", items),
             r = c(r_all, r_excl, r_amb, r_chan, unname(r_item))),
  file.path(FIG_DIR, "Data_06_Correlations.csv"))


## ===========================================================================
## 6. Anchor sensitivity  (Reviewer 2)
## ===========================================================================
cat("\n=== 6. anchor sensitivity ===\n")

anchors <- unique(d$anchor)
anchor_stats <- data.frame()
for (mt in PRIMARY_METRICS) {
  for (it in items) {
    sub <- d[d$item == it & !d$is_anchor, ]
    ## restrict to variants scored under every anchor
    common <- Reduce(intersect, lapply(split(sub, sub$anchor),
                                       function(x) as.character(x$variant)))
    sub <- sub[as.character(sub$variant) %in% common, ]
    mm <- to_matrix(sub, mt, "anchor")
    mm <- mm[, common, drop = FALSE]
    kw <- kendall_w(mm)
    anchor_stats <- rbind(anchor_stats, data.frame(
      metric = mt, item = it, W = kw$W, p = kw$p, k = kw$k))
    cat(sprintf("%-16s %-14s Kendall W across anchors = %.3f (k = %d)\n",
                mt, it, kw$W, kw$k))
  }
}
write_figure_data(anchor_stats, file.path(FIG_DIR, "Data_07_AnchorSensitivity.csv"))

for (i in seq_len(nrow(anchor_stats))) {
  r <- anchor_stats[i, ]
  put_value(sprintf("Wanchor%s%s", ifelse(r$metric == "LS", "LS", "OV"),
                    gsub("[^A-Za-z]", "", r$item)), r$W, 2)
}
put_value("WanchorOverallMin", min(anchor_stats$W[anchor_stats$metric == "overall_measure"]), 2)
put_value("WanchorLSMin", min(anchor_stats$W[anchor_stats$metric == "LS"]), 2)

## Does the family ordering survive a channel-based anchor?
##
## The comparison must be made over one fixed set of formats. Every variant
## that serves as an anchor is therefore excluded throughout -- not merely the
## anchor of the moment -- because a format scored against a near neighbour
## (7OA judged against 5OA, say) would otherwise enter one column and not the
## others and manufacture the very asymmetry being tested.
anchor_free <- setdiff(levels(droplevels(d$variant)), anchors)
fam_gap <- do.call(rbind, lapply(c(PRIMARY_METRICS), function(mt)
  do.call(rbind, lapply(anchors, function(a) {
    x <- d[d$anchor == a & as.character(d$variant) %in% anchor_free, ]
    amb  <- mean(x[[mt]][x$family == "Ambisonics"])
    chan <- mean(x[[mt]][x$family == "Channel/Object"])
    data.frame(metric = mt, anchor = a, anchor_family =
                 ifelse(a %in% c("7OA", "5OA"), "Ambisonics", "Channel/Object"),
               amb = amb, chan = chan, gap = amb - chan,
               n_amb = sum(x$family == "Ambisonics"),
               n_chan = sum(x$family == "Channel/Object"))
  }))))
cat("\nAmbisonics minus Channel/Object mean, by anchor (anchors excluded):\n")
print(fam_gap, row.names = FALSE, digits = 3)
write_figure_data(fam_gap, file.path(FIG_DIR, "Data_08_FamilyGapByAnchor.csv"))

## Per item, to show whether the pattern replicates rather than being driven by
## one recording.
fam_gap_item <- do.call(rbind, lapply(c(PRIMARY_METRICS), function(mt)
  do.call(rbind, lapply(items, function(it)
    do.call(rbind, lapply(anchors, function(a) {
      x <- d[d$anchor == a & d$item == it &
               as.character(d$variant) %in% anchor_free, ]
      data.frame(metric = mt, item = it, anchor = a,
                 gap = mean(x[[mt]][x$family == "Ambisonics"]) -
                       mean(x[[mt]][x$family == "Channel/Object"]))
    }))))))
write_figure_data(fam_gap_item, file.path(FIG_DIR, "Data_08b_FamilyGapByAnchorItem.csv"))

for (mt in PRIMARY_METRICS) {
  g <- fam_gap[fam_gap$metric == mt, ]
  gi <- fam_gap_item[fam_gap_item$metric == mt, ]
  flips <- sign(g$gap[g$anchor_family == "Ambisonics"][1]) !=
           sign(g$gap[g$anchor_family == "Channel/Object"][1])
  reps <- sum(tapply(gi$gap, gi$item, function(v)
    sign(v[1]) != sign(v[length(v)])))
  cat(sprintf("%-16s family gap flips with anchor family: %s (replicates in %d/%d items)\n",
              mt, flips, reps, length(items)))
  put_value(paste0("gapSceneAnchor", if (mt == "LS") "LS" else "OV"),
            g$gap[g$anchor == "7OA"], 3)
  put_value(paste0("gapChanAnchor", if (mt == "LS") "LS" else "OV"),
            g$gap[g$anchor == "Atmos"], 3)
  put_value(paste0("gapFiveAnchor", if (mt == "LS") "LS" else "OV"),
            g$gap[g$anchor == "5OA"], 3)
  put_value(paste0("gapFlipItems", if (mt == "LS") "LS" else "OV"), reps, 0)
}


## ===========================================================================
## 7. Spatial cue diagnostics referred to JNDs  (Reviewer 2)
## ===========================================================================
cat("\n=== 7. cue diagnostics vs JND ===\n")

jnd <- aggregate(cbind(ITDdiff_us, ILDdiff_dB) ~ variant, data = P, FUN = mean)
jnd$ITD_x_JND <- jnd$ITDdiff_us / ITD_JND_US
jnd$ILD_x_JND <- jnd$ILDdiff_dB / ILD_JND_DB
jnd <- jnd[order(jnd$ITDdiff_us), ]
print(jnd, row.names = FALSE, digits = 3)
write_figure_data(jnd, file.path(FIG_DIR, "Data_09_CueDiagnostics.csv"))

cat(sprintf("\nformats below the %.0f us ITD JND: %s\n", ITD_JND_US,
            paste(jnd$variant[jnd$ITDdiff_us < ITD_JND_US], collapse = ", ")))
cat(sprintf("formats below the %.1f dB ILD JND: %s\n", ILD_JND_DB,
            paste(jnd$variant[jnd$ILDdiff_dB < ILD_JND_DB], collapse = ", ")))

put_value("ITDjndUs", ITD_JND_US, 0)
put_value("ILDjndDb", ILD_JND_DB, 1)
put_value("nBelowITDjnd", sum(jnd$ITDdiff_us < ITD_JND_US), 0)
put_value("nBelowILDjnd", sum(jnd$ILDdiff_dB < ILD_JND_DB), 0)
put_value("itdBest", jnd$ITDdiff_us[which.min(jnd$ITDdiff_us)], 1)
put_value("tbeLSmean", mean(P$LS[P$variant == "2OA-TBE"]), 3)
put_value("tbeLSsd",   stats::sd(P$LS[P$variant == "2OA-TBE"]), 3)
put_value("maxITDus", max(jnd$ITDdiff_us), 1)
put_value("maxILDdb", max(jnd$ILDdiff_dB), 2)

## How far do the threshold comparisons depend on the reference value chosen?
put_value("ITDpermissiveUs",     ITD_PERMISSIVE_US, 0)
put_value("ILDdynamicDb",        ILD_DYNAMIC_DB, 1)
put_value("nAboveITDjnd",        sum(jnd$ITDdiff_us > ITD_JND_US), 0)
put_value("nAboveITDpermissive", sum(jnd$ITDdiff_us > ITD_PERMISSIVE_US), 0)
put_value("nAboveILDjnd",        sum(jnd$ILDdiff_dB > ILD_JND_DB), 0)
put_value("nAboveILDdynamic",    sum(jnd$ILDdiff_dB > ILD_DYNAMIC_DB), 0)
cat(sprintf("ITD above %g us: %d of %d; above %g us: %d\n", ITD_JND_US,
            sum(jnd$ITDdiff_us > ITD_JND_US), nrow(jnd), ITD_PERMISSIVE_US,
            sum(jnd$ITDdiff_us > ITD_PERMISSIVE_US)))
cat(sprintf("ILD above %g dB: %d of %d; above %g dB: %d\n", ILD_JND_DB,
            sum(jnd$ILDdiff_dB > ILD_JND_DB), nrow(jnd), ILD_DYNAMIC_DB,
            sum(jnd$ILDdiff_dB > ILD_DYNAMIC_DB)))


## ===========================================================================
## 8. Euclidean distance from the reference
## ===========================================================================
cat("\n=== 8. distance from reference ===\n")

## z-score within item so that each item contributes comparably, then measure
## distance in the two-dimensional primary-metric space.
dist_rows <- do.call(rbind, lapply(split(d[d$anchor == "7OA", ], d[d$anchor == "7OA", ]$item,
                                         drop = TRUE), function(x) {
  z <- function(v) (v - mean(v)) / stats::sd(v)
  zo <- z(x$overall_measure); zl <- z(x$LS)
  ref <- which(x$is_anchor)
  data.frame(item = x$item, variant = x$variant, is_anchor = x$is_anchor,
             dist = sqrt((zo - zo[ref])^2 + (zl - zl[ref])^2))
}))
dist_rows <- dist_rows[!dist_rows$is_anchor, ]
dsum <- aggregate(dist ~ variant, data = dist_rows, FUN = mean)
dsum <- dsum[order(dsum$dist), ]
print(dsum, row.names = FALSE, digits = 3)
write_figure_data(dist_rows, file.path(FIG_DIR, "Data_10_Deviation.csv"))

put_value("eucMin", min(dsum$dist), 2)
put_value("eucMax", max(dsum$dist), 2)
put_value("eucBest", as.character(dsum$variant[1]))
put_value("eucWorst", as.character(dsum$variant[nrow(dsum)]))


## ===========================================================================
## 9. Within-category metric discrimination
## ===========================================================================
cat("\n=== 9. within-category CV ===\n")

cvtab <- do.call(rbind, lapply(c(PRIMARY_METRICS, "ILDdiff", "ITDdiff"), function(mt)
  do.call(rbind, lapply(levels(P$family), function(fm)
    do.call(rbind, lapply(items, function(it) {
      x <- P[[mt]][P$family == fm & P$item == it]
      data.frame(metric = mt, family = fm, item = it, cv = cv(x))
    }))))))
cvagg <- aggregate(cv ~ metric + family, data = cvtab, FUN = mean)
print(cvagg, row.names = FALSE, digits = 3)
write_figure_data(cvtab, file.path(FIG_DIR, "Data_11_WithinCategoryCV.csv"))

getcv <- function(mt, fm) cvagg$cv[cvagg$metric == mt & cvagg$family == fm]
put_value("CVambLS", getcv("LS", "Ambisonics"), 3)
put_value("CVchanLS", getcv("LS", "Channel/Object"), 3)
put_value("CVambOverall", getcv("overall_measure", "Ambisonics"), 3)
put_value("CVchanOverall", getcv("overall_measure", "Channel/Object"), 3)


## ===========================================================================
## 10. Headline BINAQUAL range
## ===========================================================================
put_value("LSmin", min(P$LS), 3)
put_value("LSmax", max(P$LS), 3)
put_value("LSrange", max(P$LS) - min(P$LS), 3)
put_value("overallMin", min(P$overall_measure), 3)
put_value("overallMax", max(P$overall_measure), 3)
put_value("LSmeanRange", max(P$LS_mean) - min(P$LS_mean), 3)
put_value("LSmeanRatio", (max(P$LS_mean) - min(P$LS_mean)) / (max(P$LS) - min(P$LS)), 1)

## ===========================================================================
## 11. Excerpt stability  (does the choice of analysis window drive the result?)
## ===========================================================================
seg_path <- file.path(DATA_DIR, "metrics_long_segments.csv")
if (file.exists(seg_path)) {
  cat("\n=== 11. excerpt stability ===\n")
  sg <- utils::read.csv(seg_path, stringsAsFactors = FALSE)
  sg <- sg[sg$anchor == "7OA" & sg$is_anchor == 0, ]
  for (v in c("overall_measure", "LS")) sg[[v]] <- as.numeric(sg[[v]])
  n_seg <- length(unique(sg$segment))

  ## Per (item, variant) mean over segments, against the single centred excerpt.
  key <- function(x) paste(x$item, x$variant, sep = "|")
  P$k <- key(P); sg$k <- key(sg)
  for (mt in PRIMARY_METRICS) {
    m <- aggregate(sg[[mt]], by = list(k = sg$k), FUN = mean)
    v <- aggregate(sg[[mt]], by = list(k = sg$k), FUN = stats::sd)
    j <- merge(data.frame(k = P$k, centred = P[[mt]]),
               data.frame(k = m$k, segmean = m$x, segsd = v$x), by = "k")
    tau  <- stats::cor(j$centred, j$segmean, method = "kendall")
    mad  <- mean(abs(j$centred - j$segmean))
    cat(sprintf("%-16s Kendall tau(centred, %d-segment mean) = %+.3f   "
                , mt, n_seg, tau))
    cat(sprintf("mean |diff| = %.4f   mean within-item SD = %.4f\n",
                mad, mean(j$segsd, na.rm = TRUE)))
    put_value(paste0("tauExcerpt", if (mt == "LS") "LS" else "OV"), tau, 2)
    put_value(paste0("madExcerpt", if (mt == "LS") "LS" else "OV"), mad, 4)
    put_value(paste0("sdExcerpt",  if (mt == "LS") "LS" else "OV"),
              mean(j$segsd, na.rm = TRUE), 4)
    write_figure_data(j, file.path(FIG_DIR,
      sprintf("Data_12_ExcerptStability_%s.csv", mt)))
  }
  put_value("nSegments", n_seg, 0)
  P$k <- NULL
}

source(file.path(HERE, "figures.R"), local = TRUE)
write_values(VALUES)
cat("\ndone.\n")
