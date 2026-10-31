#' Predict from a fitted PINN
#'
#' Evaluates the trained network at new points.
#'
#' @param object A `pinn_fit`.
#' @param newdata Data frame with one column per domain variable. When
#'   omitted, the `times` given to [pinn_ode()] are used for ODE problems,
#'   and otherwise a regular grid (201 points in 1D, 101 x 101 in 2D).
#' @param ... Unused.
#' @return A data frame with the domain variables followed by one column
#'   per output.
#' @examplesIf torch::torch_is_installed()
#' decay <- function(t, y, parms) list(-parms["k"] * y)
#' prob <- pinn_ode(decay, y0 = c(y = 1), times = c(0, 5), parms = c(k = 0.5))
#' fit <- pinn_fit(prob, hidden = c(16, 16), epochs = 1000, seed = 1)
#' predict(fit, data.frame(time = c(0, 1, 2)))
#' @export
predict.pinn_fit <- function(object, newdata = NULL, ...) {
  newdata <- prediction_points(object$problem, newdata)
  if (!is.null(object$windows)) {
    return(by_window(object, newdata, function(f, nd) predict(f, nd)))
  }
  model <- model_from_fit(object)
  vars <- object$problem$domain$vars
  u <- with_no_grad({
    model$forward(model$to_coords(newdata, grad = FALSE), fitted_params(object))
  })
  out <- newdata[vars]
  for (o in object$problem$outputs) out[[o]] <- tensor_to_numeric(u[[o]])
  out
}

#' Equation residuals of a fitted PINN
#'
#' Evaluates the equation residual at new points. Values close to zero mean
#' the network satisfies the equation there; large values show where the
#' solution is unreliable.
#'
#' @inheritParams predict.pinn_fit
#' @return A data frame with the domain variables followed by one residual
#'   column per equation.
#' @export
residuals.pinn_fit <- function(object, newdata = NULL, ...) {
  newdata <- prediction_points(object$problem, newdata)
  if (!is.null(object$windows)) {
    return(by_window(object, newdata, function(f, nd) residuals(f, nd)))
  }
  model <- model_from_fit(object)
  vars <- object$problem$domain$vars
  r <- model$residual_list(model$to_coords(newdata, grad = TRUE),
                           fitted_params(object))
  labels <- names(r)
  if (is.null(labels) || any(labels == "")) {
    labels <- if (length(r) == length(object$problem$outputs)) {
      object$problem$outputs
    } else {
      paste0("eq", seq_along(r))
    }
  }
  out <- newdata[vars]
  n <- nrow(newdata)
  for (i in seq_along(r)) {
    val <- if (is_tensor(r[[i]])) tensor_to_numeric(r[[i]]$detach()) else as.numeric(r[[i]])
    out[[paste0("residual_", labels[i])]] <- rep_len(val, n)
  }
  out
}

#' Estimated parameters
#'
#' @param object A `pinn_fit`.
#' @param ... Unused.
#' @return Named numeric vector of estimated unknown parameters (empty if
#'   the problem had none).
#' @export
coef.pinn_fit <- function(object, ...) {
  object$coefficients
}

#' @export
print.pinn_fit <- function(x, ...) {
  p <- x$problem
  cat("<pinn_fit>\n")
  cat(sprintf("  Outputs %s on %s\n", paste(p$outputs, collapse = ", "),
              paste(sprintf("%s in [%s, %s]", p$domain$vars,
                            fmt_num(p$domain$lower), fmt_num(p$domain$upper)),
                    collapse = ", ")))
  s <- x$settings
  cat(sprintf("  Network %s, %s activation\n",
              paste(c(length(p$domain$vars), s$hidden, length(p$outputs)),
                    collapse = "-"), s$activation))
  if (!is.null(x$windows)) {
    cat(sprintf("  Time marching over %d windows\n", length(x$windows)))
  }
  cat(sprintf("  Trained %d Adam steps%s%s in %.1f s%s%s\n", s$epochs,
              if (s$lbfgs_iter > 0) sprintf(" + up to %d L-BFGS iterations", s$lbfgs_iter) else "",
              if (!is.null(x$windows)) " per window" else "",
              x$elapsed, if (x$interrupted) " (interrupted)" else "",
              if (isTRUE(x$diverged)) " (diverged; best weights restored)" else ""))
  f <- x$final_loss
  cat(sprintf("  Final loss%s %s (residual %s, conditions %s, data %s)\n",
              if (!is.null(x$windows)) " (worst window)" else "",
              fmt_num(f[["total"]]), fmt_num(f[["residual"]]),
              fmt_num(f[["conditions"]]), fmt_num(f[["data"]])))
  if (length(x$coefficients)) {
    cat("  Estimated parameters:\n")
    print(x$coefficients, digits = 4)
  }
  invisible(x)
}

#' @export
summary.pinn_fit <- function(object, ...) {
  structure(list(fit = object, history = object$history), class = "summary.pinn_fit")
}

#' @export
print.summary.pinn_fit <- function(x, ...) {
  print(x$fit$problem)
  cat("\n")
  print(x$fit)
  h <- x$history
  if (nrow(h) > 1) {
    first <- h$total[1]
    last <- utils::tail(h$total, 1)
    cat(sprintf("  Loss fell by a factor of %s over training.\n",
                fmt_num(first / last)))
  }
  invisible(x)
}

#' Plot a fitted PINN
#'
#' @param x A `pinn_fit`.
#' @param type `"loss"` for the training history, `"solution"` for the
#'   fitted outputs (1D and 2D domains), or `"parameters"` for the path of
#'   estimated parameters during training.
#' @param output For 2D solutions, which output to draw.
#' @param ... Passed to the underlying base graphics function.
#' @return `x`, invisibly.
#' @export
plot.pinn_fit <- function(x, type = c("loss", "solution", "parameters"),
                          output = NULL, ...) {
  type <- match.arg(type)
  switch(type,
         loss = plot_loss(x, ...),
         solution = plot_solution(x, output, ...),
         parameters = plot_parameters(x, ...))
  invisible(x)
}

plot_loss <- function(x, ...) {
  h <- x$history[x$history$phase != "final", , drop = FALSE]
  cols <- c("total", "residual", "conditions", "data")
  cols <- cols[vapply(cols, function(cl) any(h[[cl]] > 0), logical(1))]
  y <- as.matrix(h[cols])
  y[y <= 0] <- NA
  graphics::matplot(h$step, y, type = "l", lty = 1, log = "y",
                    xlab = "Step", ylab = "Loss", col = seq_along(cols), ...)
  graphics::legend("topright", legend = cols, col = seq_along(cols), lty = 1,
                   bty = "n")
  lb <- h$step[h$phase == "lbfgs"]
  if (length(lb)) graphics::abline(v = min(lb), lty = 3, col = "grey50")
}

plot_solution <- function(x, output = NULL, ...) {
  p <- x$problem
  vars <- p$domain$vars
  if (length(vars) == 1) {
    pr <- predict(x, line_grid(p$domain))
    y <- as.matrix(pr[p$outputs])
    graphics::matplot(pr[[vars]], y, type = "l", lty = 1,
                      col = seq_along(p$outputs), xlab = vars, ylab = "Value", ...)
    if (!is.null(p$data)) {
      for (i in seq_along(p$outputs)) {
        o <- p$outputs[i]
        if (o %in% names(p$data)) {
          graphics::points(p$data[[vars]], p$data[[o]], col = i, pch = 16, cex = 0.7)
        }
      }
    }
    if (length(p$outputs) > 1) {
      graphics::legend("topright", legend = p$outputs,
                       col = seq_along(p$outputs), lty = 1, bty = "n")
    }
  } else if (length(vars) == 2) {
    output <- output %||% p$outputs[1]
    if (!output %in% p$outputs) stop("Unknown `output`.", call. = FALSE)
    pr <- predict(x)
    g1 <- sort(unique(pr[[vars[1]]]))
    g2 <- sort(unique(pr[[vars[2]]]))
    z <- matrix(pr[[output]], nrow = length(g1), ncol = length(g2))
    graphics::image(g1, g2, z, xlab = vars[1], ylab = vars[2], main = output,
                    col = grDevices::hcl.colors(64, "viridis"), ...)
    graphics::contour(g1, g2, z, add = TRUE, drawlabels = FALSE,
                      col = grDevices::adjustcolor("white", 0.6))
  } else {
    stop("Solution plots are available for 1D and 2D domains; use predict() for higher dimensions.",
         call. = FALSE)
  }
}

# A dense 1D grid, so a plotted curve is smooth even when the ODE `times`
# are few.
line_grid <- function(domain, n = 201) {
  stats::setNames(data.frame(seq(domain$lower[[1]], domain$upper[[1]],
                                 length.out = n)), domain$vars)
}

plot_parameters <- function(x, ...) {
  est <- names(x$coefficients)
  if (length(est) == 0) stop("This problem has no unknown parameters.", call. = FALSE)
  h <- x$history
  graphics::matplot(h$step, as.matrix(h[est]), type = "l", lty = 1,
                    col = seq_along(est), xlab = "Step", ylab = "Estimate", ...)
  graphics::legend("topright", legend = est, col = seq_along(est), lty = 1,
                   bty = "n")
}

#' Save and load fitted PINNs
#'
#' Torch modules cannot be stored with [saveRDS()] directly. `pinn_save()`
#' stores the network weights as plain arrays alongside the rest of the fit,
#' and `pinn_load()` rebuilds the network.
#'
#' @param fit A `pinn_fit`.
#' @param path File path, conventionally ending in `.rds`.
#' @return `pinn_save()` returns `path` invisibly; `pinn_load()` returns a
#'   `pinn_fit`.
#' @export
pinn_save <- function(fit, path) {
  if (!inherits(fit, "pinn_fit")) stop("`fit` must be a pinn_fit.", call. = FALSE)
  saveRDS(strip_net(fit), path)
  invisible(path)
}

strip_net <- function(fit) {
  if (!is.null(fit$windows)) {
    fit$windows <- lapply(fit$windows, strip_net)
    return(fit)
  }
  fit$net_state <- lapply(fit$net$state_dict(), function(t) {
    as_array(t$detach()$cpu())
  })
  fit$net <- NULL
  fit
}

#' @rdname pinn_save
#' @export
pinn_load <- function(path) {
  obj <- readRDS(path)
  if (!inherits(obj, "pinn_fit") ||
      (is.null(obj$net_state) && is.null(obj$windows))) {
    stop("This file was not written by pinn_save().", call. = FALSE)
  }
  restore_net(obj)
}

restore_net <- function(obj) {
  if (!is.null(obj$windows)) {
    obj$windows <- lapply(obj$windows, restore_net)
    obj$settings$device <- "cpu"
    return(obj)
  }
  s <- obj$settings
  p <- obj$problem
  net <- pinn_mlp(length(p$domain$vars), s$hidden, length(p$outputs),
                  s$activation)
  dtype <- torch_dtype_from(s$precision)
  net$to(dtype = dtype)
  net$load_state_dict(lapply(obj$net_state, function(a) {
    r_tensor(a, dtype = dtype)
  }))
  obj$net <- net
  obj$net_state <- NULL
  obj$settings$device <- "cpu"
  obj
}

# helpers ---------------------------------------------------------------

model_from_fit <- function(fit) {
  s <- fit$settings
  build_model(fit$problem, fit[["net"]], torch_dtype_from(s$precision),
              torch_device(s$device))
}

fitted_params <- function(fit) {
  c(fit$problem$parms, as.list(fit$coefficients))
}

tensor_to_numeric <- function(t) as.numeric(as_array(t$cpu()))

prediction_points <- function(problem, newdata) {
  vars <- problem$domain$vars
  if (is.null(newdata)) return(default_grid(problem))
  newdata <- as.data.frame(newdata)
  miss <- setdiff(vars, names(newdata))
  if (length(miss)) {
    stop(sprintf("`newdata` is missing column(s): %s.", paste(miss, collapse = ", ")),
         call. = FALSE)
  }
  for (v in vars) {
    if (!is.numeric(newdata[[v]]) || anyNA(newdata[[v]])) {
      stop(sprintf("`newdata$%s` must be numeric without missing values.", v),
           call. = FALSE)
    }
  }
  newdata
}

default_grid <- function(problem) {
  dom <- problem$domain
  if (identical(problem$meta$type, "ode")) {
    return(stats::setNames(data.frame(problem$meta$times), dom$vars))
  }
  axis <- function(v, n) seq(dom$lower[[v]], dom$upper[[v]], length.out = n)
  if (length(dom$vars) == 1) {
    return(stats::setNames(data.frame(axis(dom$vars, 201)), dom$vars))
  }
  if (length(dom$vars) == 2) {
    g <- expand.grid(axis(dom$vars[1], 101), axis(dom$vars[2], 101))
    return(stats::setNames(g, dom$vars))
  }
  stop("Please supply `newdata` for problems with more than two variables.",
       call. = FALSE)
}
