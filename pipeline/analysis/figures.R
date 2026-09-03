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
  ## Default axis padding accounts only for the data range, so the extra
  ## room on the right keeps tags placed beside the rightmost markers -- the
  ## three coincident 7OA self-comparisons, at the same (overall_measure,
  ## LS) since a signal compared to itself is identical regardless of item
  ## -- inside the plot region.
  xr <- range(W$overall_measure)
  xr <- xr + c(-0.05, 0.22) * diff(xr)
  plot(W$overall_measure, W$LS, type = "n", bty = "n", xlim = xr,
       xlab = "BAM-Q overall measure", ylab = "BINAQUAL LS")
  ## Every point gets a small numeric tag (full variant names collide badly
  ## in the congested low-score cluster; one- and two-digit tags do not),
  ## resolved to names by the key drawn top left. The three coincident 7OA
  ## self-comparisons share one tag.
  vorder <- names(sort(tapply(W$LS, droplevels(W$variant), mean),
                       decreasing = TRUE))
  vnum <- setNames(seq_along(vorder), vorder)
  lab <- unique(data.frame(px = W$overall_measure, py = W$LS,
                           tag = vnum[as.character(W$variant)]))
  ## Markers are drawn large enough to carry their tag inside. Where two
  ## tags would collide on the page, one of them is detached instead and
  ## joined to its marker by a leader (see the placement search below).
  cex_pt <- 1.8
  cex_anchor <- 2.3
  cex_lab <- 0.5
  is_ref <- lab$tag == 1
  ux <- par("usr"); pin <- par("pin")
  xin <- (lab$px - ux[1]) / (ux[2] - ux[1]) * pin[1]
  yin <- (lab$py - ux[3]) / (ux[4] - ux[3]) * pin[2]
  sx <- pin[1] / (ux[2] - ux[1]); sy <- pin[2] / (ux[4] - ux[3])
  pad <- 0.015
  crowd_pad <- -0.015
  ## Crowding is decided by whether the tags themselves would collide, not
  ## whether the markers do: a digit is much smaller than the marker that
  ## carries it, so two markers can touch or even overlap slightly while
  ## their digits, each near its own centre, stay clear of each other.
  ## Testing marker-to-marker distance (one marker diameter) flagged many
  ## points as crowded that were in fact legible in place; the test is now a
  ## rectangle overlap between each pair of digits' own text boxes. strwidth
  ## /strheight measure the full advance box, which is wider than a digit's
  ## visible ink, so crowd_pad is negative: it trims that built-in slack
  ## back down to where two numerals actually start to visually collide,
  ## rather than where their nominal boxes first touch.
  tw_all <- sapply(as.character(lab$tag), strwidth, cex = cex_lab) * sx
  th <- strheight("8", cex = cex_lab) * sy
  halfw <- tw_all / 2 + crowd_pad; halfh <- rep(th / 2 + crowd_pad, length(tw_all))
  dxm <- abs(outer(xin, xin, "-")); dym <- abs(outer(yin, yin, "-"))
  overlaps <- dxm < outer(halfw, halfw, "+") & dym < outer(halfh, halfh, "+")
  diag(overlaps) <- FALSE
  crowded <- apply(overlaps, 1, any)
  ## The automatic rectangle test cleared a few markers in the densest pocket
  ## of the low-score cluster that turned out, on visual inspection of the
  ## rendered figure, still too hard to read in place; those are detached by
  ## hand here rather than by further retuning the general rule.
  lab_item <- vapply(seq_len(nrow(lab)), function(i) {
    m <- W[abs(W$overall_measure - lab$px[i]) < 1e-9 & abs(W$LS - lab$py[i]) < 1e-9, ]
    as.character(unique(m$item))[1]
  }, character(1))
  force_detach <- c("5 BigBand", "5 DeusExMachina", "7 DeusExMachina",
                    "12 BigBand", "10 DeusExMachina")
  crowded <- crowded | (paste(lab$tag, lab_item) %in% force_detach)
  for (it in items) {
    s <- W[W$item == it, ]
    points(s$overall_measure, s$LS, pch = PCH_ITEM[[it]],
           bg = ifelse(s$is_anchor, "white", COL_ITEM[[it]]),
           col = ifelse(s$is_anchor, COL_ITEM[[it]], "white"),
           cex = ifelse(s$is_anchor, cex_anchor, cex_pt), lwd = 1.4)
  }
  ## Tags inside uncrowded markers (white on the filled item colours, dark
  ## on the white-filled reference marker).
  inside <- !crowded
  text(lab$px[inside], lab$py[inside], labels = lab$tag[inside],
       cex = cex_lab, font = 2,
       col = ifelse(is_ref[inside], "grey20", "white"))
  ## Detached tags are placed by search, all in inches: for each crowded
  ## marker, try 12 directions at 5 increasing distances and take the first
  ## spot whose text box clears every marker, every tag already placed and
  ## the plot edge. The leader runs from the marker's centre to the nearest
  ## edge of the numeral's box, so it always touches the numeral.
  rad <- ifelse(is_ref, 0.19 * cex_anchor, 0.19 * cex_pt) * par("csi")
  angles <- c(0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180) * pi / 180
  ## The search below tries directions in a fixed order and keeps the first
  ## clear one, so it does not know which side of the marker a human would
  ## rather see the tag on; a couple of tags landed on the wrong side of
  ## their marker for this dense pocket and get their own preferred order
  ## (still falling through to the rest of the ring if none of those clear).
  angle_pref <- list(
    "10 DeusExMachina" =
      c(-120, -150, 180, -90, 150, 120, -60, 90, 60, 30, -30, 0) * pi / 180,
    "12 BigBand" =
      c(-90, -60, -120, -30, -150, 0, 180, 30, 150, 60, 120, 90) * pi / 180)
  ## Where the leader touches its marker also defaults to the centre, which
  ## reads badly for a few markers once several tags in the same pocket are
  ## detached; nudged off-centre, as a fraction of the marker's own radius
  ## so it stays inside the marker rather than heading towards its edge.
  touch_pref <- list("10 DeusExMachina" = c(-0.4, -0.3), "7 DeusExMachina" = c(0.3, 0.4),
                     "12 BigBand" = c(-0.4, 0), "8 DeusExMachina" = c(-0.6, -0.3),
                     "12 DeusExMachina" = c(-0.3, -0.85))
  placed <- matrix(numeric(0), ncol = 4)
  clear_of <- function(x1, x2, y1, y2) {
    cx <- pmin(pmax(xin, x1), x2); cy <- pmin(pmax(yin, y1), y2)
    if (any(sqrt((cx - xin)^2 + (cy - yin)^2) < rad + pad)) return(FALSE)
    if (nrow(placed) && any(x1 < placed[, 2] + pad & x2 > placed[, 1] - pad &
                            y1 < placed[, 4] + pad & y2 > placed[, 3] - pad))
      return(FALSE)
    x1 >= 0 && x2 <= pin[1] && y1 >= 0 && y2 <= pin[2]
  }
  for (i in which(crowded)) {
    tw <- tw_all[i]
    spot <- NULL
    key_i <- paste(lab$tag[i], lab_item[i])
    angles_i <- if (!is.null(angle_pref[[key_i]])) angle_pref[[key_i]] else angles
    for (d in rad[i] + c(0.06, 0.13, 0.21, 0.30, 0.40)) {
      for (a in angles_i) {
        cxt <- xin[i] + d * cos(a); cyt <- yin[i] + d * sin(a)
        box <- c(cxt - tw / 2 - 0.01, cxt + tw / 2 + 0.01,
                 cyt - th / 2 - 0.01, cyt + th / 2 + 0.01)
        if (clear_of(box[1], box[2], box[3], box[4])) { spot <- c(cxt, cyt, box); break }
      }
      if (!is.null(spot)) break
    }
    if (is.null(spot)) {          # nothing clear: fall back to due right
      cxt <- xin[i] + rad[i] + 0.12; cyt <- yin[i]
      spot <- c(cxt, cyt, cxt - tw / 2, cxt + tw / 2, cyt - th / 2, cyt + th / 2)
    }
    ## A couple of automatically placed tags still sat awkwardly once other
    ## nearby tags were force-detached around them; nudged by hand, as
    ## fractions of the tag's own box so the shift scales with its size.
    nd <- switch(key_i,
                "7 DeusExMachina" = c(0, 0.9),
                "12 DeusExMachina" = c(-0.6, 0),
                "12 BigBand" = c(-1.5, 0.58),
                NULL)
    if (!is.null(nd)) {
      ddx <- nd[1] * tw; ddy <- nd[2] * th
      spot <- spot + c(ddx, ddy, ddx, ddx, ddy, ddy)
    }
    placed <- rbind(placed, spot[3:6])
    tof <- touch_pref[[key_i]]; if (is.null(tof)) tof <- c(0, 0)
    ox <- xin[i] + tof[1] * rad[i]; oy <- yin[i] + tof[2] * rad[i]
    dxv <- spot[1] - ox; dyv <- spot[2] - oy
    Lv <- max(sqrt(dxv^2 + dyv^2), 1e-9); u1 <- dxv / Lv; u2 <- dyv / Lv
    tt <- 0.85 * min(if (abs(u1) > 1e-9) (tw / 2) / abs(u1) else Inf,
                     if (abs(u2) > 1e-9) (th / 2) / abs(u2) else Inf)
    segments(ux[1] + ox / sx,                    ux[3] + oy / sy,
             ux[1] + (spot[1] - u1 * tt) / sx,    ux[3] + (spot[2] - u2 * tt) / sy,
             col = "grey40", lwd = 0.6)
    text(ux[1] + spot[1] / sx, ux[3] + spot[2] / sy, labels = lab$tag[i],
         adj = c(0.5, 0.5), cex = cex_lab, col = "grey30")
  }
  leg_cex <- 0.62
  key <- legend("topleft",
                legend = paste0(vnum, "  ", names(vnum)),
                bty = "n", cex = leg_cex, ncol = 2, text.col = "grey20",
                title = "variant key", title.cex = leg_cex)
  ## No separate "7OA reference" swatch: anchor points keep each item's own
  ## shape and outline colour, just white-filled, so no single glyph would
  ## represent them accurately. The caption states the open-marker convention
  ## in words instead.
  ## Item (shape) legend directly below the variant key, drawn by hand so
  ## the markers' left edges sit on the key's text column, the labels use
  ## the same size as the key, and the rows use the same row-to-row spacing
  ## the key itself used (its first two column-1 entries, 1 and 2, give that
  ## spacing directly), rather than an independently guessed multiple of the
  ## character height.
  cwl <- par("cxy")[1] * leg_cex
  chl <- par("cxy")[2] * leg_cex
  rowspace <- key$text$y[1] - key$text$y[2]
  x0 <- key$text$x[1]
  ys <- key$rect$top - key$rect$h - 0.75 * chl - (seq_along(items) - 1) * rowspace
  points(rep(x0 + 0.85 * cwl, length(items)), ys, pch = PCH_ITEM[items],
         bg = COL_ITEM[items], col = "white", cex = 1.0, lwd = 0.8)
  text(x0 + 2.0 * cwl, ys, ITEM_LABEL[items], adj = c(0, 0.5),
       cex = leg_cex, col = "grey20")
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
with_device(fig(5, "AnchorSensitivity"), 9.0, 5.3, function() {
  ## The wide left margin carries the variant labels, which squeezes the plot
  ## region; without extra room on the right the panel (b) title runs off the
  ## device.  Hence the wider right margin and slightly smaller title.  The
  ## bottom outer margin carries the shared anchor legend, which previously sat
  ## inside panel (a) and overlapped the lowest format rows.
  op <- par(mfrow = c(1, 2), mar = c(4.2, 8.6, 2.4, 1.4), mgp = c(2.5, 0.7, 0),
            las = 1, cex.axis = 0.8, cex.main = 0.95, tcl = -0.3,
            oma = c(2.2, 0, 0, 0))
  on.exit(par(op), add = TRUE)
  ## Offset the three anchors vertically within each format row.  Drawn at a
  ## common y they coincide wherever two anchors give a similar mean, which hid
  ## the 7OA points nearly everywhere: 7OA is plotted first, so the two later
  ## anchors covered it and only two of the three colours were ever visible.
  dodge <- setNames(seq(0.24, -0.24, length.out = length(COL_ANCHOR)),
                    names(COL_ANCHOR))
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
    ## One band per format row, tall enough to enclose the dodged points.  Drawn
    ## in user units so it tracks the dodge rather than a fixed line width.
    rect(par("usr")[1], y - 0.42, par("usr")[2], y + 0.42,
         col = "grey94", border = NA)
    for (a in names(COL_ANCHOR)) {
      s <- sub[sub$anchor == a, ]
      if (!nrow(s)) next
      mu <- tapply(s[[mt]], droplevels(s$variant), mean)
      points(mu[names(y)], y + dodge[[a]], pch = PCH_ANCHOR[[a]],
             bg = COL_ANCHOR[[a]], col = "white", cex = 1.25)
    }
  }
  ## Shared legend in the bottom outer margin, clear of both panels.
  op2 <- par(fig = c(0, 1, 0, 1), oma = c(0, 0, 0, 0), mar = c(0, 0, 0, 0),
             new = TRUE)
  plot(0, 0, type = "n", axes = FALSE, xlab = "", ylab = "")
  legend("bottom", horiz = TRUE, bty = "n", cex = 0.75, pt.cex = 1.25,
         legend = paste("anchor:", names(COL_ANCHOR)),
         pch = unname(PCH_ANCHOR[names(COL_ANCHOR)]),
         pt.bg = unname(COL_ANCHOR), col = "white")
  par(op2)
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
with_device(fig(8, "ReferenceAnchorBias"), 7.2, 4.2, function() {
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
