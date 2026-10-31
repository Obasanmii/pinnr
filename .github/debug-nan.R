# Round 4: which part of L-BFGS's first closure call produces the NaN?
# Round 2: plain torch gives NaN at L-BFGS's first closure call (float64, arm64).
# Round 3: evaluating the loss inside L-BFGS's grad-mode switch is fine.
# Here the closure (zero_grad + loss + backward) is reproduced piece by piece.
library(callr)
cat("Host:", R.version$platform, "|", r(function() paste("torch", packageVersion("torch"))), "\n\n")

probe <- function(variant, dtype_name) {
  library(torch)
  set.seed(1); torch_manual_seed(1)
  dt <- if (dtype_name == "float64") torch_float64() else torch_float32()
  lin <- function(i, o) { l <- nn_linear(i, o); nn_init_xavier_normal_(l$weight); nn_init_zeros_(l$bias); l }
  sine <- nn_module(forward = function(x) torch_sin(x))
  net <- nn_sequential(lin(1, 8), sine(), lin(8, 8), sine(), lin(8, 1))
  net$to(dtype = dt)
  pts <- function() torch_tensor(matrix(runif(1000, 0, 2), ncol = 1), dtype = dt, requires_grad = TRUE)
  loss_fn <- function(t) {
    y <- 1 + (t / 2) * net(t - 1)
    dy <- autograd_grad(list(y), list(t), list(torch_ones_like(y)), create_graph = TRUE)[[1]]
    (dy + y)$pow(2)$mean()
  }
  # identical to round 2: Adam with resampling
  t <- pts()
  opt <- optim_adam(net$parameters, lr = 1e-3)
  for (ep in 1:100) {
    if (ep > 1 && (ep - 1) %% 25 == 0) t <- pts()
    opt$zero_grad(); L <- loss_fn(t); L$backward(); opt$step()
  }
  f <- function(x) if (is.finite(x)) sprintf("%.4g", x) else "NaN"
  w_ok <- function() all(vapply(net$parameters, function(p) as.logical(torch_isfinite(p)$all()$item()), TRUE))
  g_ok <- function() all(vapply(net$parameters, function(p) {
    if (is_undefined_tensor(p$grad)) TRUE else as.logical(torch_isfinite(p$grad)$all()$item())
  }, TRUE))

  lb <- optim_lbfgs(net$parameters, lr = 1, max_iter = 20, tolerance_grad = 1e-9,
                    tolerance_change = 1e-12, history_size = 50,
                    line_search_fn = "strong_wolfe")
  log <- character()
  closure <- function() {
    w_in <- w_ok()
    if (variant != "no zero_grad") lb$zero_grad()
    w_zero <- w_ok()
    L <- loss_fn(if (variant == "fresh t") t$detach()$requires_grad_(TRUE) else t)
    before <- L$item()
    if (variant != "no backward") L$backward()
    after <- L$item()
    if (!length(log)) log <<- sprintf("weights in %s, after zero_grad %s | loss %s, after backward %s | grads finite %s",
                                      w_in, w_zero, f(before), f(after), g_ok())
    L
  }

  start <- f(loss_fn(t)$item())
  if (variant == "manual (no L-BFGS)") {
    (function() { local_no_grad(); with_enable_grad(closure()) })()
  } else {
    try(lb$step(closure), silent = TRUE)
  }
  sprintf("start %s | first call: %s | after: weights %s, loss %s",
          start, log, w_ok(), f(loss_fn(t)$item()))
}

N <- 3
for (dtn in c("float64", "float32")) {
  for (v in c("as round 2", "manual (no L-BFGS)", "no zero_grad", "no backward", "fresh t")) {
    if (dtn == "float32" && v != "as round 2") next
    cat(sprintf("%s, %s:\n", dtn, v))
    for (i in seq_len(N)) cat("  ", r(probe, args = list(v, dtn)), "\n")
  }
}
