# Time marching for ODE problems: one network per time window, each window
# starting from the state predicted at the end of the previous one.

fit_windows <- function(problem, windows, settings) {
  m <- problem$meta
  if (!identical(m$type, "ode") || !isTRUE(m$hard_initial)) {
    stop("`windows` is available for problems from pinn_ode() with hard_initial = TRUE.",
         call. = FALSE)
  }
  if (length(problem$unknown$init)) {
    stop("`windows` cannot be combined with unknown parameters; estimate parameters over the whole time range instead.",
         call. = FALSE)
  }
  tvar <- m$time
  breaks <- seq(problem$domain$lower[[1]], problem$domain$upper[[1]],
                length.out = windows + 1)
  y0 <- m$y0
  fits <- vector("list", windows)
  for (k in seq_len(windows)) {
    lo <- breaks[k]
    hi <- breaks[k + 1]
    dat <- problem$data
    if (!is.null(dat)) {
      dat <- dat[dat[[tvar]] >= lo & dat[[tvar]] <= hi, , drop = FALSE]
      if (nrow(dat) == 0) dat <- NULL
    }
    times_k <- c(lo, m$times[m$times > lo & m$times < hi], hi)
    sub <- pinn_ode(m$func, y0 = y0, times = times_k, parms = problem$parms,
                    data = dat, time = tvar, hard_initial = TRUE)
    if (isTRUE(settings$verbose)) {
      message(sprintf("Window %d of %d: %s in [%s, %s]", k, windows, tvar,
                      fmt_num(lo), fmt_num(hi)))
    }
    args <- settings
    if (!is.null(settings$seed)) args$seed <- settings$seed + k - 1
    fits[[k]] <- do.call(pinn_fit, c(list(problem = sub), args))
    # the call made by do.call() inlines the whole problem; drop it
    fits[[k]]$call <- NULL
    if (fits[[k]]$interrupted) {
      fits <- fits[seq_len(k)]
      breaks <- breaks[seq_len(k + 1)]
      break
    }
    end <- predict(fits[[k]], stats::setNames(data.frame(hi), tvar))
    y0 <- unlist(end[names(m$y0)])
  }

  offset <- 0
  hist <- lapply(seq_along(fits), function(k) {
    h <- fits[[k]]$history
    h$window <- k
    h$step <- h$step + offset
    offset <<- max(h$step)
    h
  })
  finals <- do.call(rbind, lapply(fits, `[[`, "final_loss"))

  structure(
    list(
      net = NULL,
      windows = fits,
      breaks = breaks,
      problem = problem,
      coefficients = stats::setNames(numeric(0), character(0)),
      history = do.call(rbind, hist),
      final_loss = apply(finals, 2, max),
      settings = c(fits[[1]]$settings, list(windows = length(fits))),
      interrupted = any(vapply(fits, `[[`, logical(1), "interrupted")),
      diverged = any(vapply(fits, `[[`, logical(1), "diverged")),
      elapsed = sum(vapply(fits, `[[`, numeric(1), "elapsed"))
    ),
    class = "pinn_fit"
  )
}

# Which window each time belongs to.
window_index <- function(fit, times) {
  findInterval(times, fit$breaks, rightmost.closed = TRUE, all.inside = TRUE)
}

# Apply a per-window function (predict or residuals) and reassemble rows.
by_window <- function(fit, newdata, fun) {
  tvar <- fit$problem$domain$vars
  idx <- window_index(fit, newdata[[tvar]])
  out <- NULL
  for (k in unique(idx)) {
    rows <- which(idx == k)
    part <- fun(fit$windows[[k]], newdata[rows, , drop = FALSE])
    if (is.null(out)) {
      out <- part[rep(NA_integer_, nrow(newdata)), , drop = FALSE]
    }
    out[rows, ] <- part
  }
  rownames(out) <- NULL
  out
}
