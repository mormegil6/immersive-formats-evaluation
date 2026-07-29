## common.R -- shared constants, loading and helpers for the revision analysis.
##
## Deliberately base-R only: no tidyverse, no ggplot2, no external packages.
## The analysis therefore runs unchanged on any R >= 4.0 without a package
## installation step, which is the practical meaning of "reusable" for a
## supplementary analysis.

## ---------------------------------------------------------------- constants

## BAM-Q internals needed to give the diagnostic cue measures physical units.
##
## The waveform is resampled to 44.1 kHz on entry, but the binaural features are
## resampled again to 6 kHz before the back end runs (BAMQFrontEnd sets
## fsNew = 6000; Fleszner et al. 2017, Sec. 1.1: "All interaural features are
## time sequences and are resampled to 6 kHz after computation to reduce the
## computational complexity in the back-end").  The back end then blocks at
## blockLenFac * fsNew, so a 400 ms frame is 2400 samples and not 17 640.  This
## is the divisor that converts the accumulated ILD measure into decibels, so
## getting it wrong rescales every reported ILD magnitude.
BAMQ_FS            <- 6000
BAMQ_BLOCK_FACTOR  <- 0.4
BAMQ_BLOCK_SAMPLES <- round(BAMQ_BLOCK_FACTOR * BAMQ_FS)   # 2400

## Perceptual reference values for the just-noticeable-difference framing.
## ITD: Klumpp & Eady (1956), Mossop & Culling (1998) -- ~10-20 us for
## broadband and low-frequency signals; the conservative bound is used.
## ILD: Mills (1960), Grantham (1984) -- ~0.5-1 dB; the conservative bound is
## used.
## Reference discrimination thresholds. Both are favourable-case values from
## simple, steady stimuli near the median plane, not conservative bounds.
ITD_JND_US <- 20      # attributed to Klumpp & Eady (1956) by Klockgether &
                      # van de Par (2016); their own broadband figure is 10 us
ILD_JND_DB <- 1.0     # Mills (1960): ~1 dB at 1 kHz, ~0.5 dB above 1.5 kHz

## Least favourable thresholds found in the same literature, used to report how
## far the threshold comparisons depend on the value chosen.
ITD_PERMISSIVE_US <- 62    # Mossop & Culling (1998) p. 1575, worst subject at
                           # zero reference delay (range 12.3-62.2 us)
ILD_DYNAMIC_DB    <- 4.4   # Grantham (1984) p. 73, 50 Hz modulation rate at
                           # 1 and 4 kHz (9.6 dB at 500 Hz)

## Model-defined bounds.
BINQ_IDENTICAL   <- 100     # binQ: 100 = no difference
LS_IDENTICAL     <- 1       # BINAQUAL LS for reference vs itself

PRIMARY_METRICS    <- c("overall_measure", "LS")
DIAGNOSTIC_METRICS <- c("ILDdiff", "ITDdiff")

## Canonical display order: Ambisonic orders descending, then native
## channel/object formats, then the 42pIKO-derived chain.
VARIANT_ORDER <- c("7OA", "5OA", "3OA-IAMF", "2OA-TBE", "1OA-YT", "42pIKO",
                   "Atmos", "Auro3D", "Sony360RA",
                   "42pIKO-Atmos", "42pIKO-Auro3D", "42pIKO-Sony360RA")

ITEM_ORDER <- c("DeusExMachina", "BigBand", "KWARTET")
ITEM_LABEL <- c(DeusExMachina = "Deus Ex Machina (choir)",
                BigBand        = "Big Band (jazz)",
                KWARTET        = "Kwartet (quartet)")

## Colour-blind-safe palette (Okabe & Ito), used consistently across figures.
COL_ITEM   <- c(DeusExMachina = "#0072B2", BigBand = "#D55E00", KWARTET = "#009E73")
COL_FAMILY <- c("Ambisonics" = "#0072B2", "Channel/Object" = "#D55E00")
COL_ANCHOR <- c("7OA" = "#0072B2", "5OA" = "#E69F00", "Atmos" = "#CC79A7")
## Shape as well as colour, so the anchors stay separable in greyscale print and
## under colour-vision deficiency: the 5OA and Atmos hues differ by only about
## 11 of 255 greyscale levels, i.e. not at all once the figure is printed B&W.
## Deliberately not the PCH_ITEM set (21/22/24) beyond the shared circle.
PCH_ANCHOR <- c("7OA" = 21, "5OA" = 23, "Atmos" = 25)
PCH_ITEM   <- c(DeusExMachina = 21, BigBand = 22, KWARTET = 24)

## ------------------------------------------------------------------ loading

load_metrics <- function(path) {
  d <- utils::read.csv(path, stringsAsFactors = FALSE)
  num <- c("SNR_dc", "SNR_ac", "SNR_dc_fix", "SNR_ac_fix", "OPM", "OPM_fix",
           "binQ", "ILDdiff", "ITDdiff", "IVSdiff", "overall_measure",
           "vnsim_0", "vnsim_1", "LS", "LS_mean",
           "lag_samples", "lag_ms", "gcc_corr", "lufs_before", "gain_db",
           "analysed_duration_s")
  for (v in intersect(num, names(d))) d[[v]] <- as.numeric(d[[v]])

  d$item    <- factor(d$item, levels = ITEM_ORDER)
  d$variant <- factor(d$variant, levels = VARIANT_ORDER)
  d$family  <- factor(d$family, levels = c("Ambisonics", "Channel/Object"))
  d$is_anchor <- as.integer(d$is_anchor) == 1L

  ## Diagnostic cue measures in physical units (see BAMQ_BLOCK_SAMPLES above).
  d$ITDdiff_us <- d$ITDdiff * 1e6
  d$ILDdiff_dB <- d$ILDdiff / BAMQ_BLOCK_SAMPLES
  d
}

## Primary analysis view: 7OA anchor, excluding each item's self-comparison.
primary <- function(d, anchor = "7OA", drop_anchor_row = TRUE) {
  x <- d[d$anchor == anchor, ]
  if (drop_anchor_row) x <- x[!x$is_anchor, ]
  x$variant <- droplevels(x$variant)
  x
}

## ---------------------------------------------------------------- statistics

## Ranks within each item (1 = best). `higher_better` flips the direction for
## measures where a larger value means a worse match to the reference.
rank_within_item <- function(d, metric, higher_better = TRUE) {
  s <- split(d, d$item, drop = TRUE)
  out <- lapply(s, function(x) {
    v <- x[[metric]]
    x$rank <- rank(if (higher_better) -v else v, ties.method = "average")
    x
  })
  do.call(rbind, out)
}

## Kendall's coefficient of concordance across blocks, derived from the
## Friedman statistic: W = chi2 / (n * (k - 1)).  W = 1 means the blocks
## (content items, or anchors) rank the treatments identically; W = 0 means no
## agreement beyond chance.
kendall_w <- function(mat) {
  mat <- as.matrix(mat)                 # rows = blocks, cols = treatments
  mat <- mat[stats::complete.cases(mat), , drop = FALSE]
  n <- nrow(mat); k <- ncol(mat)
  if (n < 2 || k < 3) return(list(W = NA_real_, chi2 = NA_real_, df = NA_integer_,
                                  p = NA_real_, n = n, k = k))
  r <- t(apply(mat, 1, rank))
  Rj <- colSums(r)
  S  <- sum((Rj - mean(Rj))^2)
  W  <- 12 * S / (n^2 * (k^3 - k))
  chi2 <- n * (k - 1) * W
  list(W = W, chi2 = chi2, df = k - 1,
       p = stats::pchisq(chi2, k - 1, lower.tail = FALSE), n = n, k = k)
}

## Monte-Carlo permutation p-value for Kendall's W.
##
## Kendall and Babington Smith (1939, pp. 278 ff.) show that the chi-squared
## reference distribution for W fits poorly in the tails when the number of
## rankings is small, and give exact tables instead. With n = 3 blocks the
## chi-squared p-value above is therefore not trustworthy. Exact enumeration is
## infeasible here ((k!)^n permutations), so the null distribution is obtained
## by Monte-Carlo sampling: under the null each block ranks the k treatments
## independently and uniformly at random. The seed is fixed so the reported
## p-value is reproducible.
KENDALL_PERM_B    <- 100000L
KENDALL_PERM_SEED <- 20260728L

## Format a Monte-Carlo p-value as a complete comparison. A sampled p-value can
## never be exactly zero, so small values are reported as a bound rather than
## printed as 0.000. The bound is the conventional 0.001 rather than the
## attainable resolution 1/(B+1): reporting "< 0.00001" is precise about what
## was computed but reads as false precision. The replicate count is given in
## the Methods, so the actual resolution remains recoverable.
fmt_perm_p <- function(p, B = KENDALL_PERM_B) {
  if (is.na(p)) return("= NA")
  if (p < 0.001) return("< 0.001")
  sprintf("= %.3f", p)
}

kendall_w_perm <- function(mat, B = KENDALL_PERM_B, seed = KENDALL_PERM_SEED) {
  mat <- as.matrix(mat)
  mat <- mat[stats::complete.cases(mat), , drop = FALSE]
  n <- nrow(mat); k <- ncol(mat)
  if (n < 2 || k < 3) return(NA_real_)
  W_obs <- kendall_w(mat)$W
  set.seed(seed)
  Rj <- matrix(0L, B, k)
  for (i in seq_len(n)) {
    keys <- matrix(stats::runif(B * k), B, k)
    Rj <- Rj + t(apply(keys, 1, order))     # one uniform random ranking per row
  }
  S_null <- rowSums((Rj - n * (k + 1) / 2)^2)
  W_null <- 12 * S_null / (n^2 * (k^3 - k))
  (1 + sum(W_null >= W_obs - 1e-12)) / (B + 1)
}

## Wide matrix of a metric: rows = blocks (item or anchor), cols = variants.
to_matrix <- function(d, metric, block = "item") {
  blocks <- unique(as.character(d[[block]]))
  vars   <- levels(droplevels(d$variant))
  m <- matrix(NA_real_, length(blocks), length(vars),
              dimnames = list(blocks, vars))
  for (i in seq_len(nrow(d))) {
    m[as.character(d[[block]][i]), as.character(d$variant[i])] <- d[[metric]][i]
  }
  m
}

## Correlation with a descriptive-only framing: the format set is exhaustive
## rather than sampled, so no p-value is attached.
descr_cor <- function(x, y, method = "pearson") {
  ok <- is.finite(x) & is.finite(y)
  if (sum(ok) < 3) return(NA_real_)
  stats::cor(x[ok], y[ok], method = method)
}

cv <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) < 2 || mean(x) == 0) return(NA_real_)
  stats::sd(x) / abs(mean(x))
}

## ------------------------------------------------------------------- output

## LaTeX \newcommand macro emitter, so every number quoted in the manuscript is
## generated from the data rather than typed by hand.
values_env <- new.env(parent = emptyenv())
values_env$lines <- character(0)

put_value <- function(name, value, digits = 3, percent = FALSE) {
  v <- if (is.character(value)) value
       else if (percent) sprintf("%.1f\\%%", 100 * value)
       else formatC(value, format = "f", digits = digits)
  values_env$lines <- c(values_env$lines,
                        sprintf("\\newcommand{\\%s}{%s}", name, v))
  invisible(v)
}

write_values <- function(path) {
  hdr <- c("%% values.tex -- generated by pipeline/analysis/analysis.R",
           "%% Do not edit by hand; re-run the analysis instead.", "")
  writeLines(c(hdr, values_env$lines), path)
  message("values -> ", path, " (", length(values_env$lines), " macros)")
}

write_figure_data <- function(df, path) {
  utils::write.csv(df, path, row.names = FALSE)
  invisible(path)
}

## Render the same plotting function to a vector PDF (for LaTeX) and a raster
## PNG (for quick inspection).  `draw` takes no arguments.
with_device <- function(basepath, width, height, draw) {
  ## cairo_pdf, not pdf().  R's own PostScript/PDF device maps the ASCII hyphen
  ## onto the font's "minus" glyph, so format names like 42pIKO-Atmos came out
  ## as 42pIKO<minus>Atmos.  cairo_pdf writes a real hyphen.  Fall back to
  ## pdf() where cairo is unavailable, accepting the minus there.
  if (capabilities("cairo")) {
    grDevices::cairo_pdf(paste0(basepath, ".pdf"), width = width,
                         height = height)
  } else {
    grDevices::pdf(paste0(basepath, ".pdf"), width = width, height = height,
                   useDingbats = FALSE)
  }
  draw(); grDevices::dev.off()
  grDevices::png(paste0(basepath, ".png"), width = width, height = height,
                 units = "in", res = 300)
  draw(); grDevices::dev.off()
  message("figure -> ", basepath, ".{pdf,png}")
}

## Horizontal dot plot: one row per variant, one point per content item, with a
## mean marker.  Used for every per-format figure so the panels read alike.
dotplot_by_variant <- function(df, value, order_by = NULL, xlab = "",
                               main = "", ref_line = NULL, ref_label = NULL,
                               log_x = FALSE, legend_pos = "bottomright") {
  vars <- if (is.null(order_by)) rev(levels(droplevels(df$variant))) else rev(order_by)
  y <- setNames(seq_along(vars), vars)
  xs <- df[[value]]
  xlim <- range(c(xs, ref_line), na.rm = TRUE)
  xlim <- xlim + c(-0.06, 0.06) * diff(xlim)
  if (log_x) xlim <- range(c(xs[xs > 0], ref_line), na.rm = TRUE) * c(0.7, 1.4)

  op <- par(mar = c(3.8, 8.2, 2.0, 1.6), mgp = c(2.3, 0.6, 0), las = 1,
            cex.axis = 0.78, cex.main = 0.95, cex.lab = 0.85, tcl = -0.3)
  on.exit(par(op), add = TRUE)
  plot(NA, xlim = xlim, ylim = c(0.4, length(vars) + 0.6),
       xlab = xlab, ylab = "", yaxt = "n", main = main,
       log = if (log_x) "x" else "", bty = "n")
  axis(2, at = y, labels = names(y), tick = FALSE, cex.axis = 0.75)
  abline(h = y, col = "grey92", lwd = 6, lend = 1)
  if (!is.null(ref_line)) {
    abline(v = ref_line, lty = 2, col = "grey35")
    if (!is.null(ref_label))
      mtext(ref_label, side = 3, at = ref_line, cex = 0.7, col = "grey25", line = 0.1)
  }
  for (it in levels(droplevels(df$item))) {
    s <- df[df$item == it, ]
    points(s[[value]], y[as.character(s$variant)] + 0,
           pch = PCH_ITEM[[it]], bg = COL_ITEM[[it]], col = "white", cex = 1.25, lwd = 0.8)
  }
  mu <- tapply(df[[value]], droplevels(df$variant), mean)
  segments(mu[names(y)], y - 0.28, mu[names(y)], y + 0.28, lwd = 2.2, col = "grey15")
  if (!identical(legend_pos, "none")) {
    legend(legend_pos, legend = ITEM_LABEL[levels(droplevels(df$item))],
           pch = PCH_ITEM[levels(droplevels(df$item))],
           pt.bg = COL_ITEM[levels(droplevels(df$item))], col = "white",
           bty = "n", cex = 0.7, pt.cex = 1.1)
  }
  invisible(y)
}

## Shared horizontal item legend, drawn in the figure's outer bottom margin so
## it never collides with the data. Call after the last panel; the device must
## have been opened with a bottom `oma`.
outer_item_legend <- function(its, extra_labels = NULL, extra_pch = NULL,
                              extra_bg = NULL, extra_col = NULL) {
  op <- par(fig = c(0, 1, 0, 1), oma = c(0, 0, 0, 0), mar = c(0, 0, 0, 0),
            new = TRUE)
  on.exit(par(op), add = TRUE)
  plot(0, 0, type = "n", axes = FALSE, xlab = "", ylab = "")
  legend("bottom", horiz = TRUE, bty = "n", cex = 0.72, pt.cex = 1.15,
         legend = c(unname(ITEM_LABEL[its]), extra_labels),
         pch     = c(unname(PCH_ITEM[its]), extra_pch),
         pt.bg   = c(unname(COL_ITEM[its]), extra_bg),
         col     = c(rep("white", length(its)), extra_col))
}
