## figures.R -- all manuscript figures, base R graphics.
## Sourced from analysis.R with local = TRUE; expects P, d, cond, items,
## FIG_DIR and (optionally) lat / has_noalign in scope.

fig <- function(n, name) file.path(FIG_DIR, sprintf("Fig_%02d_%s", n, name))

ord_overall <- as.character(
  summ$variant[order(summ$overall_measure_mean, decreasing = TRUE)])


## --- Fig 1: latency sensitivity of the two models --------------------------
if (has_noalign) {
  with_device(fig(1, "LatencySensitivity"), 7.2, 4.4, function() {
    op <- par(mfrow = c(1, 2), mar = c(4.3, 4.3, 2.6, 1), mgp = c(2.4, 0.7, 0),
              tcl = -0.3, cex.axis = 0.85)
    on.exit(par(op), add = TRUE)

    ## (a) BINAQUAL: uncorrected LS tracks renderer latency
    xr <- range(c(lat$abs_ms[lat$abs_ms > 0], 0.05))
    plot(pmax(lat$abs_ms, 0.05), lat$LS_u, log = "x", xlim = xr,
         ylim = range(c(lat$LS_u, lat$LS_a)),
         xlab = "uncorrected transport latency (ms)",
         ylab = "BINAQUAL localisation similarity  LS",
         main = "(a) BINAQUAL", bty = "n", type = "n")
    for (it in items) {
      s <- lat[lat$item == it, ]
      points(pmax(s$abs_ms, 0.05), s$LS_u, pch = PCH_ITEM[[it]],
             bg = COL_ITEM[[it]], col = "white", cex = 1.2)
      points(pmax(s$abs_ms, 0.05), s$LS_a, pch = PCH_ITEM[[it]],
             bg = "white", col = COL_ITEM[[it]], cex = 1.2)
      segments(pmax(s$abs_ms, 0.05), s$LS_u, pmax(s$abs_ms, 0.05), s$LS_a,
               col = adjustcolor(COL_ITEM[[it]], 0.45))
    }
    legend("topright", c("uncorrected", "latency-corrected"),
           pch = 21, pt.bg = c("grey30", "white"), col = c("white", "grey30"),
           bty = "n", cex = 0.75)

    ## (b) BAM-Q: essentially unaffected
    plot(pmax(lat$abs_ms, 0.05), lat$ov_u, log = "x", xlim = xr,
         ylim = range(c(lat$ov_u, lat$ov_a)),
         xlab = "uncorrected transport latency (ms)",
         ylab = "BAM-Q overall measure",
         main = "(b) BAM-Q", bty = "n", type = "n")
    for (it in items) {
      s <- lat[lat$item == it, ]
      points(pmax(s$abs_ms, 0.05), s$ov_u, pch = PCH_ITEM[[it]],
             bg = COL_ITEM[[it]], col = "white", cex = 1.2)
      points(pmax(s$abs_ms, 0.05), s$ov_a, pch = PCH_ITEM[[it]],
             bg = "white", col = COL_ITEM[[it]], cex = 1.2)
      segments(pmax(s$abs_ms, 0.05), s$ov_u, pmax(s$abs_ms, 0.05), s$ov_a,
               col = adjustcolor(COL_ITEM[[it]], 0.45))
    }
    legend("bottomleft", ITEM_LABEL[items], pch = PCH_ITEM[items],
           pt.bg = COL_ITEM[items], col = "white", bty = "n", cex = 0.72)
  })
}


## --- Fig 2: primary metrics by format --------------------------------------
with_device(fig(2, "PrimaryMetrics"), 7.6, 5.0, function() {
  op <- par(mfrow = c(1, 2), oma = c(2.0, 0, 0, 0)); on.exit(par(op), add = TRUE)
  dotplot_by_variant(P, "overall_measure", ord_overall,
                     xlab = "BAM-Q overall measure",
                     main = "(a) perceptual quality", legend_pos = "none")
  dotplot_by_variant(P, "LS", ord_overall,
                     xlab = "BINAQUAL localisation similarity  LS",
                     main = "(b) localisation similarity", legend_pos = "none")
  outer_item_legend(items)
})


## --- Fig 3: quality space --------------------------------------------------
with_device(fig(3, "QualitySpace"), 5.6, 5.0, function() {
  op <- par(mar = c(4.3, 4.3, 1.2, 1), mgp = c(2.5, 0.7, 0), tcl = -0.3,
            cex.axis = 0.85)
  on.exit(par(op), add = TRUE)
  W <- d[d$anchor == "7OA", ]
  plot(W$overall_measure, W$LS, type = "n", bty = "n",
       xlab = "BAM-Q overall measure", ylab = "BINAQUAL LS")
  for (it in items) {
    s <- W[W$item == it, ]
    fam <- ifelse(s$family == "Ambisonics", 1, 2)
    points(s$overall_measure, s$LS, pch = PCH_ITEM[[it]],
           bg = ifelse(s$is_anchor, "white", COL_ITEM[[it]]),
           col = ifelse(s$is_anchor, COL_ITEM[[it]], "white"),
           cex = ifelse(s$is_anchor, 1.7, 1.2), lwd = 1.4)
    text(s$overall_measure, s$LS, labels = as.character(s$variant),
         pos = 4, cex = 0.5, col = "grey35", offset = 0.35)
  }
  legend("topleft", c(ITEM_LABEL[items], "7OA reference"),
         pch = c(PCH_ITEM[items], 21),
         pt.bg = c(COL_ITEM[items], "white"),
         col = c(rep("white", length(items)), "grey30"),
         bty = "n", cex = 0.72)
})


## --- Fig 4: distance from reference ----------------------------------------
with_device(fig(4, "DeviationFromReference"), 5.6, 4.6, function() {
  op <- par(oma = c(2.0, 0, 0, 0)); on.exit(par(op), add = TRUE)
  ord <- as.character(dsum$variant)
  dotplot_by_variant(dist_rows, "dist", rev(ord),
                     xlab = "normalised Euclidean distance from 7OA reference",
                     legend_pos = "none")
  outer_item_legend(items)
})


## --- Fig 5: anchor sensitivity ---------------------------------------------
with_device(fig(5, "AnchorSensitivity"), 7.4, 5.0, function() {
  ## The wide left margin carries the variant labels, which squeezes the plot
  ## region; without extra room on the right the panel (b) title runs off the
  ## device.  Hence the wider right margin and slightly smaller title.
  op <- par(mfrow = c(1, 2), mar = c(4.2, 9.5, 2.4, 2.6), mgp = c(2.5, 0.7, 0),
            las = 1, cex.axis = 0.8, cex.main = 0.95, tcl = -0.3)
  on.exit(par(op), add = TRUE)
  for (mt in c("overall_measure", "LS")) {
    sub <- d[!d$is_anchor, ]
    vars <- rev(ord_overall)
    y <- setNames(seq_along(vars), vars)
    xs <- sub[[mt]]
    plot(NA, xlim = range(xs) + c(-0.05, 0.05) * diff(range(xs)),
         ylim = c(0.4, length(vars) + 0.6), yaxt = "n", bty = "n", ylab = "",
         xlab = if (mt == "LS") "BINAQUAL LS" else "BAM-Q overall measure",
         main = if (mt == "LS") "(b) localisation similarity" else "(a) perceptual quality")
    axis(2, at = y, labels = names(y), tick = FALSE)
    abline(h = y, col = "grey92", lwd = 6, lend = 1)
    for (a in names(COL_ANCHOR)) {
      s <- sub[sub$anchor == a, ]
      if (!nrow(s)) next
      mu <- tapply(s[[mt]], droplevels(s$variant), mean)
      points(mu[names(y)], y, pch = 21, bg = COL_ANCHOR[[a]], col = "white",
             cex = 1.3)
    }
    if (mt == "overall_measure")
      legend("bottomleft", paste("anchor:", names(COL_ANCHOR)), pch = 21,
             pt.bg = COL_ANCHOR, col = "white", bty = "n", cex = 0.75)
  }
})


## --- Fig 6: cue diagnostics against JNDs -----------------------------------
with_device(fig(6, "CueDiagnostics"), 7.6, 5.0, function() {
  op <- par(mfrow = c(1, 2), oma = c(2.0, 0, 0, 0)); on.exit(par(op), add = TRUE)
  ord_itd <- as.character(jnd$variant)
  dotplot_by_variant(P, "ITDdiff_us", rev(ord_itd),
                     xlab = expression("BAM-Q ITDdiff (" * mu * "s)"),
                     main = "(a) interaural time difference",
                     ref_line = ITD_JND_US, ref_label = "ITD JND",
                     log_x = TRUE, legend_pos = "none")
  dotplot_by_variant(P, "ILDdiff_dB", rev(ord_itd),
                     xlab = "BAM-Q ILDdiff (equivalent dB)",
                     main = "(b) interaural level difference",
                     ref_line = ILD_JND_DB, ref_label = "ILD JND",
                     log_x = TRUE, legend_pos = "none")
  outer_item_legend(items)
})


## --- Fig 7: within-category discrimination ---------------------------------
with_device(fig(7, "WithinCategoryCV"), 6.0, 4.4, function() {
  op <- par(mar = c(4.2, 4.6, 1.4, 1), mgp = c(2.6, 0.7, 0), tcl = -0.3,
            cex.axis = 0.85)
  on.exit(par(op), add = TRUE)
  mt <- unique(cvagg$metric)
  bars <- sapply(mt, function(x)
    c(Ambisonics = cvagg$cv[cvagg$metric == x & cvagg$family == "Ambisonics"],
      `Channel/Object` = cvagg$cv[cvagg$metric == x & cvagg$family == "Channel/Object"]))
  bp <- barplot(bars, beside = TRUE, col = COL_FAMILY, border = NA,
                ylab = "coefficient of variation", names.arg = mt,
                ylim = c(0, max(bars, 0.16, na.rm = TRUE) * 1.15))
  abline(h = 0.15, lty = 2, col = "grey35")
  mtext("CV = 0.15", side = 4, at = 0.15, las = 1, cex = 0.7, col = "grey25")
  legend("topright", names(COL_FAMILY), fill = COL_FAMILY, border = NA,
         bty = "n", cex = 0.78)
})


## --- Fig 8: does the family ordering follow the anchor's own family? --------
## The single most direct answer to "what happens if the anchor changes": if
## each line crosses zero between the scene-based anchors and the channel-based
## one, the apparent family advantage belongs to the anchor, not the formats.
with_device(fig(8, "AnchorFamilyBias"), 7.2, 4.2, function() {
  op <- par(mfrow = c(1, 2), mar = c(4.0, 4.4, 2.2, 1.0), oma = c(2.0, 0, 0, 0),
            mgp = c(2.5, 0.7, 0), tcl = -0.3, cex.axis = 0.82, cex.main = 0.95,
            cex.lab = 0.85)
  on.exit(par(op), add = TRUE)
  titles <- c(overall_measure = "(a) BAM-Q overall measure", LS = "(b) BINAQUAL LS")
  for (mt in PRIMARY_METRICS) {
    g <- fam_gap_item[fam_gap_item$metric == mt, ]
    xs <- seq_along(anchors)
    ## zero must always be visible: it is the line the argument turns on.
    yl <- range(c(0, g$gap))
    yl <- yl + c(-0.12, 0.12) * max(diff(yl), .Machine$double.eps)
    plot(NA, xlim = c(0.8, length(anchors) + 0.2), ylim = yl,
         xaxt = "n", bty = "n", xlab = "reference anchor",
         ylab = "Ambisonic - Channel/Object", main = titles[[mt]])
    axis(1, at = xs, labels = anchors)
    abline(h = 0, col = "grey40", lty = 2)
    ## shade which family each anchor belongs to
    mtext(c("scene-based", "scene-based", "channel-based"), side = 3, at = xs,
          line = -0.4, cex = 0.6, col = "grey45")
    for (it in items) {
      v <- sapply(anchors, function(a) g$gap[g$item == it & g$anchor == a][1])
      lines(xs, v, col = adjustcolor(COL_ITEM[[it]], 0.75), lwd = 1.8)
      points(xs, v, pch = PCH_ITEM[[it]], bg = COL_ITEM[[it]], col = "white",
             cex = 1.25)
    }
  }
  outer_item_legend(items)
})
