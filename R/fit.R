#' Train a physics-informed neural network
#'
#' Fits a fully connected network to a [pinn_problem()] (or a problem from
#' [pinn_ode()]) by minimising
#' \deqn{w_r L_{residual} + w_c L_{conditions} + w_d L_{data},}
#' where each term is a mean squared error. Training runs `epochs` steps of
#' Adam and then, optionally, `lbfgs_iter` iterations of L-BFGS, which
#' often sharpens the solution considerably.
#'
#' @section Choosing settings: The defaults solve small problems on a CPU
#'   in seconds to minutes. If the loss stalls, try more epochs, a wider or
#'   deeper network, more collocation points, or `lbfgs_iter = 500`. For
#'   parameter estimation, a larger `lr_unknown` lets the parameters move
#'   faster than the network weights. Long time horizons are hard for
#'   PINNs; shorter windows, or more data, help.
#'
#' @section Long time horizons: PINNs often converge to a wrong, flat
#'   solution when an ODE is solved over a long horizon with fast early
#'   dynamics (for example an epidemic starting from a few cases). For
#'   problems from [pinn_ode()], `windows = k` splits the time range into
#'   `k` equal windows and trains one network per window, each starting
#'   from the end state of the previous one ("time marching"). This is
#'   available for forward problems (no `unknown` parameters).
#'
#' Pressing Esc (or Ctrl+C) stops training early and returns the model as
#' trained so far, with a warning. If the loss becomes `NaN` or infinite,
#' training stops and the weights with the lowest loss seen so far are
#' returned, also with a warning (and `diverged = TRUE` in the result).
#'
#' @param problem A `pinn_problem`.
#' @param hidden Integer vector of hidden layer widths.
#' @param activation Activation function; see [pinn_mlp()].
#' @param epochs Number of Adam steps.
#' @param lr Adam learning rate for the network weights.
#' @param lr_unknown Adam learning rate for unknown parameters. Defaults to
#'   `10 * lr`.
#' @param lbfgs_iter Number of L-BFGS iterations after Adam (0 to skip).
#' @param n_collocation Number of points inside the domain where the
#'   residual is evaluated.
#' @param sampling `"lhs"` (Latin hypercube) or `"uniform"`.
#' @param resample_every Draw new collocation and condition points every
#'   this many Adam steps (0 keeps one fixed set). Resampling reduces
#'   overfitting to the training points.
#' @param weights Named numeric vector with loss weights `residual`,
#'   `conditions` and `data`. Missing names default to 1.
#' @param precision `"float32"` (default) or `"float64"`. Double precision
#'   is slower but can help L-BFGS reach smaller losses.
#' @param device A torch device, such as `"cpu"`, `"cuda"` or `"mps"`.
#' @param seed Optional integer seed for reproducible sampling and weights.
#' @param verbose Print progress messages.
#' @param record_every Store the loss every this many steps.
#' @param windows Number of time windows for ODE problems; see *Long time
#'   horizons*.
#' @return An object of class `pinn_fit`, with methods for [predict()],
#'   [coef()], [residuals()], [plot()] and [summary()].
#' @examplesIf torch::torch_is_installed()
#' # Exponential decay dy/dt = -k y
#' decay <- function(t, y, parms) list(-parms["k"] * y)
#' prob <- pinn_ode(decay, y0 = c(y = 1), times = seq(0, 5, by = 0.5),
#'                  parms = c(k = 0.5))
#' fit <- pinn_fit(prob, hidden = c(16, 16), epochs = 1500, seed = 1)
#' head(predict(fit))
#' @export
pinn_fit <- function(problem, hidden = c(32, 32, 32), activation = "tanh",
                     epochs = 5000, lr = 1e-3, lr_unknown = NULL,
                     lbfgs_iter = 0, n_collocation = 1000,
                     sampling = c("lhs", "uniform"), resample_every = 0,
                     weights = c(residual = 1, conditions = 1, data = 1),
                     precision = c("float32", "float64"), device = "cpu",
                     seed = NULL, verbose = interactive(), record_every = 10,
                     windows = 1) {
  call <- match.call()
  if (!inherits(problem, "pinn_problem")) {
    stop("`problem` must be created with pinn_problem() or pinn_ode().",
         call. = FALSE)
  }
  windows <- check_count(windows, "windows")
  if (windows > 1) {
    settings <- list(hidden = hidden, activation = activation, epochs = epochs,
                     lr = lr, lr_unknown = lr_unknown, lbfgs_iter = lbfgs_iter,
                     n_collocation = n_collocation, sampling = sampling[1],
                     resample_every = resample_every, weights = weights,
                     precision = precision[1], device = device, seed = seed,
                     verbose = verbose, record_every = record_every)
    out <- fit_windows(problem, windows, settings)
    out$call <- call
    return(out)
  }
  if (!is.numeric(hidden) || length(hidden) == 0 ||
      any(!is.finite(hidden)) || any(hidden < 1) ||
      any(hidden != round(hidden))) {
    stop("`hidden` must be a vector of positive whole numbers.", call. = FALSE)
  }
  if (!is.character(activation) || length(activation) != 1 ||
      !activation %in% activation_names) {
    stop(sprintf("`activation` must be one of: %s.",
                 paste(activation_names, collapse = ", ")), call. = FALSE)
  }
  epochs <- check_count(epochs, "epochs", min = 0)
  lbfgs_iter <- check_count(lbfgs_iter, "lbfgs_iter", min = 0)
  if (epochs + lbfgs_iter == 0) {
    stop("Set `epochs` or `lbfgs_iter` above zero.", call. = FALSE)
  }
  lr <- check_positive(lr, "lr")
  lr_unknown <- check_positive(lr_unknown %||% (10 * lr), "lr_unknown")
  n_collocation <- check_count(n_collocation, "n_collocation")
  sampling <- match.arg(sampling)
  resample_every <- check_count(resample_every, "resample_every", min = 0)
  record_every <- check_count(record_every, "record_every")
  weights <- check_weights(weights)
  precision <- match.arg(precision)

  if (!torch_is_installed()) {
    stop("The torch backend is not installed. Run torch::install_torch() once, then try again.",
         call. = FALSE)
  }
  if (!is.null(seed)) {
    seed <- check_count(seed, "seed", min = 0)
    set.seed(seed)
    torch_manual_seed(seed)
  }

  dtype <- torch_dtype_from(precision)
  dev <- torch_device(device)
  vars <- problem$domain$vars
  outs <- problem$outputs

  net <- pinn_mlp(length(vars), as.integer(hidden), length(outs), activation)
  net$to(dtype = dtype, device = dev)
  model <- build_model(problem, net, dtype, dev)

  # Unknown parameters, on the log scale when positive.
  unk <- problem$unknown
  theta <- lapply(names(unk$init), function(k) {
    v <- if (unk$positive[[k]]) log(unk$init[[k]]) else unk$init[[k]]
    r_tensor(v, dtype = dtype, device = dev, requires_grad = TRUE)
  })
  names(theta) <- names(unk$init)
  params_now <- function() {
    est <- lapply(names(theta), function(k) {
      if (unk$positive[[k]]) theta[[k]]$exp() else theta[[k]]
    })
    c(problem$parms, stats::setNames(est, names(theta)))
  }
  unknown_now <- function() {
    vapply(names(theta), function(k) {
      v <- theta[[k]]$item()
      if (unk$positive[[k]]) exp(v) else v
    }, numeric(1))
  }

  make_points <- function() {
    list(
      col = model$to_coords(pinn_sample(n_collocation, problem$domain, sampling)),
      cond = lapply(problem$conditions, function(cn) {
        model$to_coords(pinn_sample(cn$n, problem$domain, sampling,
                                    fixed = cn$where))
      })
    )
  }
  data_t <- model$data_tensors()

  compute <- function(pts) {
    model$losses(pts, params_now(), data_t, weights)
  }

  hist <- list()
  record <- function(step, phase, vals) {
    hist[[length(hist) + 1L]] <<- c(list(step = step, phase = phase),
                                     as.list(vals), as.list(unknown_now()))
  }

  # Weights with the lowest loss seen so far, restored if training diverges.
  best <- NULL
  keep_best <- function(total) {
    if (is.null(best) || total < best$loss) {
      best <<- list(
        loss = total,
        net = lapply(net$state_dict(), function(t) t$detach()$clone()),
        theta = lapply(theta, function(t) t$detach()$clone())
      )
    }
  }
  restore_best <- function() {
    with_no_grad({
      net$load_state_dict(best$net)
      for (k in names(theta)) theta[[k]]$copy_(best$theta[[k]])
    })
  }
  # Signalled when the loss stops being finite; caught around each optimiser.
  check_finite <- function(step, total) {
    if (!is.finite(total)) {
      stop(structure(class = c("pinnr_diverged", "error", "condition"),
                     list(message = "loss is not finite", call = NULL,
                          step = step, value = total)))
    }
  }
  diverged <- NULL
  on_diverged <- function(e) diverged <<- list(step = e$step, value = e$value)
  not_finite_msg <- function(value, step) {
    sprintf("The loss became %s at step %d. Try a smaller `lr`, standardising the problem's scales, or precision = \"float64\".",
            format(value), step)
  }
  report <- function(step, phase, vals) {
    est <- unknown_now()
    extra <- if (length(est)) {
      paste0("  ", paste(sprintf("%s=%s", names(est), fmt_num(est)), collapse = " "))
    } else ""
    message(sprintf("[%s %5d] loss %s (res %s, cond %s, data %s)%s", phase, step,
                    fmt_num(vals[["total"]]), fmt_num(vals[["residual"]]),
                    fmt_num(vals[["conditions"]]), fmt_num(vals[["data"]]),
                    extra))
  }

  pts <- make_points()
  interrupted <- FALSE
  t_start <- Sys.time()
  report_every <- max(1L, epochs %/% 10L)

  if (epochs > 0) {
    opt <- optim_adam(net$parameters, lr = lr)
    opt_u <- if (length(theta)) optim_adam(theta, lr = lr_unknown) else NULL
    tryCatch({
      for (ep in seq_len(epochs)) {
        if (resample_every > 0 && ep > 1 && (ep - 1) %% resample_every == 0) {
          pts <- make_points()
        }
        opt$zero_grad()
        if (!is.null(opt_u)) opt_u$zero_grad()
        L <- compute(pts)
        L$total$backward()
        # record before stepping, so the loss matches the weights kept by keep_best()
        if (ep == 1 || ep %% record_every == 0 || ep == epochs) {
          vals <- loss_values(L)
          check_finite(ep, vals[["total"]])
          record(ep, "adam", vals)
          keep_best(vals[["total"]])
          if (verbose && (ep == 1 || ep %% report_every == 0)) report(ep, "adam", vals)
        }
        opt$step()
        if (!is.null(opt_u)) opt_u$step()
      }
    }, interrupt = function(e) {
      interrupted <<- TRUE
    }, pinnr_diverged = on_diverged)
  }

  if (lbfgs_iter > 0 && !interrupted && is.null(diverged)) {
    lb <- optim_lbfgs(c(net$parameters, theta), lr = 1, max_iter = lbfgs_iter,
                      tolerance_grad = 1e-9, tolerance_change = 1e-12,
                      history_size = 50, line_search_fn = "strong_wolfe")
    n_eval <- 0L
    closure <- function() {
      lb$zero_grad()
      L <- compute(pts)
      L$total$backward()
      n_eval <<- n_eval + 1L
      total <- L$total$item()
      check_finite(epochs + n_eval, total)
      keep_best(total)
      if (n_eval %% record_every == 0) {
        vals <- loss_values(L)
        record(epochs + n_eval, "lbfgs", vals)
        if (verbose && n_eval %% max(1L, lbfgs_iter %/% 5L) == 0) {
          report(n_eval, "lbfgs", vals)
        }
      }
      L$total
    }
    tryCatch(lb$step(closure), interrupt = function(e) {
      interrupted <<- TRUE
    }, pinnr_diverged = on_diverged)
  }

  last_step <- if (length(hist)) hist[[length(hist)]]$step else 0
  final <- loss_values(compute(pts))
  if (is.null(diverged) && !is.finite(final[["total"]])) {
    diverged <- list(step = last_step + 1, value = final[["total"]])
  }
  if (!is.null(diverged)) {
    if (is.null(best)) {
      stop(not_finite_msg(diverged$value, diverged$step), call. = FALSE)
    }
    restore_best()
    final <- loss_values(compute(pts))
    if (!is.finite(final[["total"]])) {
      stop(not_finite_msg(final[["total"]], diverged$step), call. = FALSE)
    }
    warning(paste(not_finite_msg(diverged$value, diverged$step),
                  sprintf("Returning the weights with the lowest loss seen (%s).",
                          fmt_num(best$loss))),
            call. = FALSE)
  }
  record(last_step + 1, "final", final)
  elapsed <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
  if (interrupted) {
    warning("Training was interrupted; returning the model as trained so far.",
            call. = FALSE)
  }
  if (verbose) {
    message(sprintf("Done in %.1f s. Final loss %s.", elapsed,
                    fmt_num(final[["total"]])))
  }

  structure(
    list(
      net = net,
      problem = problem,
      coefficients = unknown_now(),
      history = history_frame(hist),
      final_loss = final,
      settings = list(hidden = as.integer(hidden), activation = activation,
                      epochs = epochs, lr = lr, lr_unknown = lr_unknown,
                      lbfgs_iter = lbfgs_iter, n_collocation = n_collocation,
                      sampling = sampling, resample_every = resample_every,
                      weights = weights, precision = precision,
                      device = device, seed = seed),
      interrupted = interrupted,
      diverged = !is.null(diverged),
      elapsed = elapsed,
      call = call
    ),
    class = "pinn_fit"
  )
}

check_weights <- function(weights) {
  w <- c(residual = 1, conditions = 1, data = 1)
  if (!is.numeric(weights) || is.null(names(weights)) ||
      any(!names(weights) %in% names(w)) || any(!is.finite(weights)) ||
      any(weights < 0)) {
    stop("`weights` must be a named numeric vector with non-negative entries residual, conditions and/or data.",
         call. = FALSE)
  }
  w[names(weights)] <- weights
  w
}

loss_values <- function(L) {
  c(total = L$total$item(), residual = L$residual$item(),
    conditions = L$conditions$item(), data = L$data$item())
}

history_frame <- function(hist) {
  if (length(hist) == 0) return(data.frame())
  rows <- lapply(hist, function(h) as.data.frame(h, stringsAsFactors = FALSE))
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# The pieces shared by training and prediction: coordinate tensors, the
# scaled forward pass, data tensors and the loss terms.
build_model <- function(problem, net, dtype, dev) {
  dom <- problem$domain
  vars <- dom$vars
  outs <- problem$outputs
  lo <- dom$lower
  scale <- 2 / (dom$upper - dom$lower)

  to_coords <- function(df, grad = TRUE) {
    out <- lapply(vars, function(v) {
      r_tensor(matrix(as.numeric(df[[v]]), ncol = 1), dtype = dtype,
               device = dev, requires_grad = grad)
    })
    stats::setNames(out, vars)
  }

  forward <- function(coords, params) {
    # inputs are mapped to [-1, 1]; derivatives stay in physical units
    z <- torch_cat(lapply(vars, function(v) {
      (coords[[v]] - lo[[v]]) * scale[[v]] - 1
    }), dim = 2)
    raw <- net(z)
    u <- lapply(seq_along(outs), function(i) raw[, i, drop = FALSE])
    names(u) <- outs
    if (!is.null(problem$transform)) {
      tr <- call_with_pool(problem$transform, c(u, coords, params),
                           "The output `transform`")
      if (!is.list(tr) || is.null(names(tr)) || any(!names(tr) %in% outs)) {
        stop("The output `transform` must return a named list of outputs.",
             call. = FALSE)
      }
      u[names(tr)] <- tr
    }
    u
  }

  data_tensors <- function() {
    d <- problem$data
    if (is.null(d)) return(NULL)
    obs <- intersect(outs, names(d))
    col <- function(x) {
      r_tensor(matrix(x, ncol = 1), dtype = dtype, device = dev)
    }
    list(
      coords = to_coords(d, grad = FALSE),
      y = stats::setNames(lapply(obs, function(o) {
        col(ifelse(is.na(d[[o]]), 0, d[[o]]))
      }), obs),
      mask = stats::setNames(lapply(obs, function(o) {
        col(as.numeric(!is.na(d[[o]])))
      }), obs),
      n = stats::setNames(lapply(obs, function(o) sum(!is.na(d[[o]]))), obs)
    )
  }

  zero <- function() torch_zeros(1, dtype = dtype, device = dev)

  msq <- function(r) {
    if (is_tensor(r)) return(r$pow(2)$mean())
    r_tensor(mean(as.numeric(r)^2), dtype = dtype, device = dev)
  }
  mean_terms <- function(rs) Reduce(`+`, lapply(rs, msq)) / length(rs)

  residual_list <- function(coords, params) {
    u <- forward(coords, params)
    pool <- c(u, coords, params, list(d = pinn_d))
    as_residual_list(call_with_pool(problem$residual, pool, "The `residual` function"),
                     "The `residual` function")
  }

  losses <- function(pts, params, data_t, weights) {
    l_res <- mean_terms(residual_list(pts$col, params))

    l_cond <- zero()
    for (i in seq_along(problem$conditions)) {
      cn <- problem$conditions[[i]]
      cc <- pts$cond[[i]]
      pool <- c(forward(cc, params), cc, params, list(d = pinn_d))
      l_cond <- l_cond + cn$weight * mean_terms(cn$fn(pool))
    }

    l_data <- zero()
    if (!is.null(data_t)) {
      ud <- forward(data_t$coords, params)
      parts <- lapply(names(data_t$y), function(o) {
        ((ud[[o]] - data_t$y[[o]]) * data_t$mask[[o]])$pow(2)$sum() / data_t$n[[o]]
      })
      l_data <- Reduce(`+`, parts) / length(parts)
    }

    total <- weights[["residual"]] * l_res +
      weights[["conditions"]] * l_cond +
      weights[["data"]] * l_data
    list(total = total, residual = l_res, conditions = l_cond, data = l_data)
  }

  list(to_coords = to_coords, forward = forward, data_tensors = data_tensors,
       residual_list = residual_list, losses = losses)
}
