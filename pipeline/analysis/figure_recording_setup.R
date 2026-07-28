## figure_recording_setup.R -- schematic of the Deus Ex Machina recording setup.
##
##   Rscript figure_recording_setup.R [out_dir]
##
## Requested by a reviewer: the microphone configuration was not clear from
## prose alone.  Two panels are needed because the defining feature of this
## setup is vertical: the choir was deliberately layered in height so that the
## scene occupies the lower hemisphere as well as the horizon, which is what
## makes it a full-sphere test case and what the channel-based formats cannot
## reproduce.  A plan view alone would hide exactly the property under test.
##
## Geometry follows the production documentation (S3DAPC 2023): Aula of Gdansk
## University of Technology, 15 x 40 x 7 m; choir in a near-complete ring around
## a centrally placed third-order array; first-order array about 5 m away.
## Elevations are schematic -- the documentation records the seating tiers
## (floor / chairs / standing / platform) but not measured heights.

args <- commandArgs(trailingOnly = TRUE)
OUT <- if (length(args) >= 1) args[1] else "../../plots/revision"
## Resolve this script's own directory so that common.R is found regardless of
## the working directory the script is invoked from. sys.frame()$ofile is NULL
## under Rscript, so --file= is consulted first.
HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f[1]))
  else tryCatch(dirname(normalizePath(sys.frame(1)$ofile)), error = function(e) ".")
})
source(file.path(HERE, "common.R"))
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

## --- geometry ---------------------------------------------------------------
## Azimuth convention follows the recording: 0 deg is the array front (toward
## the sopranos), positive azimuth is to the left, and the conductor stands at
## 180 deg in the opening of the arc, behind the array. Sections are drawn on
## two depth rings because they overlap in azimuth: the men sit on the floor on
## an inner ring, and the women stand behind them, the sopranos on a riser.
ROOM_W <- 15; ROOM_L <- 40; ROOM_H <- 7
CX <- 7.5; CY <- 26          # array position = centre of the choir arc
R_IN0 <- 1.5; R_IN1 <- 2.5   # inner ring: seated on the floor
R_OUT0 <- 2.8; R_OUT1 <- 3.8 # outer ring: standing, sopranos on a riser
CONDUCTOR_AZ <- 180; CONDUCTOR_R <- 3.1
NTSF1_AZ <- 180; NTSF1_R <- 7.5   # ~5 m behind the choir edge

## Azimuth (deg, 0 = front, + = left) to plot coordinates.
az_xy <- function(az, r) {
  th <- az * pi / 180
  list(x = CX - r * sin(th), y = CY + r * cos(th))
}

## Choir sections: azimuth spans, depth ring, and seating tier.
## CONFIRM: bass azimuths (-120, 0, +120), the sopranos' riser at 0 deg and the
## conductor at 180 deg are from the production; alto and tenor spans are read
## off the 360-degree reference frame and should be checked.
sections <- data.frame(
  label = c("S", "A", "A", "T", "T", "B", "B", "B"),
  name  = c("soprano", "alto L", "alto R", "tenor L", "tenor R",
            "bass L", "bass C", "bass R"),
  a0    = c(-45,  52, -98,  38, -100, 103, -24, -137),
  a1    = c( 45,  98, -52, 100,  -38, 137,  24, -103),
  ring  = c("out", "out", "out", "in", "in", "in", "in", "in"),
  tier  = c(4, 3, 3, 2, 2, 1, 1, 1),
  stringsAsFactors = FALSE)

## Ten Behringer B5 spot microphones (production documentation, Table 1).
spots <- data.frame(
  az   = c(25, -25, 0, 75, -75, 95, -95, 120, 0, -120),
  rad  = c(4.1, 4.1, 4.3, 4.1, 4.1, 2.9, 2.9, 2.9, 2.9, 2.9),
  what = c("soprano L", "soprano R", "soloist", "alto L", "alto R",
           "tenor L", "tenor R", "bass L", "bass C", "bass R"),
  stringsAsFactors = FALSE)

## Filled arc between two radii, spanning an azimuth range (0 = front, + = left).
arc <- function(r0, r1, a0, a1, col, border = NA) {
  th <- seq(a0, a1, length.out = 60) * pi / 180
  polygon(c(CX - r0 * sin(th), rev(CX - r1 * sin(th))),
          c(CY + r0 * cos(th), rev(CY + r1 * cos(th))),
          col = col, border = border)
}

TIER_COL <- c("#0072B2", "#56B4E9", "#E69F00", "#D55E00")   # floor -> platform
TIER_NAME <- c("on floor", "on chairs", "standing", "on riser")

## --- panel (a): plan --------------------------------------------------------
panel_plan <- function() {
  par(mar = c(2.2, 1.0, 2.2, 1.0))
  lim <- 5.6
  plot(NA, xlim = c(CX - lim, CX + lim), ylim = c(CY - 10.4, CY + lim), asp = 1,
       axes = FALSE, xlab = "", ylab = "", main = "(a) plan view")

  for (i in seq_len(nrow(sections))) {
    s <- sections[i, ]
    inner <- s$ring == "in"
    r0 <- if (inner) R_IN0 else R_OUT0
    r1 <- if (inner) R_IN1 else R_OUT1
    arc(r0, r1, s$a0, s$a1, TIER_COL[s$tier])
    p <- az_xy(mean(c(s$a0, s$a1)), (r0 + r1) / 2)
    text(p$x, p$y, s$label, col = "white", font = 2, cex = 0.85)
  }

  sp <- az_xy(spots$az, spots$rad)
  points(sp$x, sp$y, pch = 21, bg = "grey20", col = "white", cex = 0.9, lwd = 0.7)

  ## front reference tick, drawn clear of the section arcs
  segments(az_xy(0, R_OUT1 + 0.15)$x, az_xy(0, R_OUT1 + 0.15)$y,
           az_xy(0, R_OUT1 + 0.60)$x, az_xy(0, R_OUT1 + 0.60)$y,
           lty = 3, col = "grey55")
  text(az_xy(0, R_OUT1 + 0.95)$x, az_xy(0, R_OUT1 + 0.95)$y,
       expression(0*degree ~ "(array front)"), cex = 0.58, col = "grey35")

  cnd <- az_xy(CONDUCTOR_AZ, CONDUCTOR_R)
  points(cnd$x, cnd$y, pch = 21, bg = "grey35", col = "white", cex = 1.1)
  text(cnd$x + 0.35, cnd$y, "conductor", cex = 0.6, adj = 0)

  points(CX, CY, pch = 21, bg = "#CC0000", col = "white", cex = 2.1, lwd = 1.2)
  text(CX, CY - 2.18, "ZM-1 (3OA)", cex = 0.62, font = 2)   # clear of the arc opening
  nt <- az_xy(NTSF1_AZ, NTSF1_R)
  points(nt$x, nt$y, pch = 21, bg = "#CC0000", col = "white", cex = 2.1, lwd = 1.2)
  text(nt$x + 0.55, nt$y, "NT-SF1 (1OA)", cex = 0.62, font = 2, adj = 0)

  arrows(CX - 0.7, CY - R_IN1, CX - 0.7, nt$y, code = 3, length = 0.04,
         col = "grey35", lwd = 0.9)
  text(CX - 0.95, mean(c(CY - R_IN1, nt$y)), "~5 m", cex = 0.62,
       col = "grey25", adj = 1, srt = 90)

  legend(CX - lim, CY - 9.6, xjust = 0, yjust = 0, horiz = TRUE, bty = "n",
         cex = 0.58, pt.cex = 0.9,
         legend = c("ambisonic array", "spot mic (10x)"),
         pch = 21, pt.bg = c("#CC0000", "grey20"), col = "white")
  mtext(sprintf("Aula, %d x %d x %d m", ROOM_W, ROOM_L, ROOM_H),
        side = 1, line = 0.4, cex = 0.58, col = "grey35")
}

## --- panel (b): height profile ----------------------------------------------
## A true cross-section would cut through only two of the eight section arcs,
## so the vertical layout is shown as a height profile instead: honest about
## what the documentation records (seating tier per section, not surveyed
## coordinates) while making the essential point visible, namely that the
## sources straddle the array axis instead of sitting on it.
panel_elev <- function() {
  par(mar = c(3.4, 3.6, 2.2, 1.0), mgp = c(2.2, 0.6, 0), tcl = -0.3,
      cex.axis = 0.75, cex.lab = 0.8)
  secs <- c("B", "T", "A", "S")
  tiers <- 1:4
  riser <- c(0, 0.45, 0, 0.35)
  ear   <- c(0.80, 1.15, 1.60, 1.95)
  ARRAY <- 1.55
  plot(NA, xlim = c(0.4, 4.6), ylim = c(0, 2.35), xaxt = "n", bty = "n",
       xlab = "", ylab = "approximate ear height (m)",
       main = "(b) vertical layering")
  axis(1, at = tiers, labels = FALSE)
  for (t in tiers) {
    mtext(secs[t], side = 1, at = t, line = 0.5, cex = 0.72, font = 2)
    mtext(TIER_NAME[t], side = 1, at = t, line = 1.45, cex = 0.55, col = "grey30")
  }
  abline(h = ARRAY, lty = 2, col = "grey45")
  text(4.55, ARRAY + 0.10, "array axis", cex = 0.6, col = "grey35", adj = 1)
  for (t in tiers) {
    if (riser[t] > 0)
      rect(t - 0.22, 0, t + 0.22, riser[t], col = "grey90", border = "grey65")
    segments(t, riser[t], t, ear[t], col = TIER_COL[t], lwd = 4, lend = 1)
    points(t, ear[t], pch = 21, bg = TIER_COL[t], col = "white", cex = 1.5, lwd = 1)
  }
  arrows(0.62, ARRAY, 0.62, 0.80, length = 0.05, col = "grey35", lwd = 1)
  text(0.68, 1.16, "below\nhorizon", cex = 0.58, col = "grey35", adj = 0)
}

with_device(file.path(OUT, "Fig_00_RecordingSetup"), 7.4, 4.0, function() {
  op <- par(mfrow = c(1, 2)); on.exit(par(op), add = TRUE)
  panel_plan(); panel_elev()
})
