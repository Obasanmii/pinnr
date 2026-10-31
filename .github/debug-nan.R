# Round 3: isolate the macOS arm64 float64 NaN without any optimiser.
# Round 2 showed plain torch gives NaN at L-BFGS's first closure call, before
# any weight changes. L-BFGS's step() runs local_no_grad() and then
# with_enable_grad(closure()). Here the same loss is evaluated in different
# grad-mode contexts, each in fresh R sessions.
library(callr)
cat("Host:", R.version$platform, "|", r(function() paste("torch", packageVersion("torch"))), "\n\n")

probe <- function(dtype_name, with_derivative, train_first) {
  library(torch)
  set.seed(1); torch_manual_seed(1)
  dt <- if (dtype_name == "float64") torch_float64() else torch_float32()
  lin <- function(i, o) { l <- nn_linear(i, o); nn_init_xavier_normal_(l$weight); nn_init_zeros_(l$bias); l }
  sine <- nn_module(forward = function(x) torch_sin(x))
  net <- nn_sequential(lin(1, 8), sine(), lin(8, 8), sine(), lin(8, 1))
  net$to(dtype = dt)
  t <- torch_tensor(matrix(runif(1000, 0, 2), ncol = 1), dtype = dt, requires_grad = TRUE)
  loss_fn <- function() {
    y <- 1 + (t / 2) * net(t - 1)
    if (with_derivative) {
      dy <- autograd_grad(list(y), list(t), list(torch_ones_like(y)), create_graph = TRUE)[[1]]
      (dy + y)$pow(2)$mean()
    } else {
      (y - torch_exp(-t))$pow(2)$mean()
    }
  }
  if (train_first) {
    opt <- optim_adam(net$parameters, lr = 1e-3)
    for (i in 1:100) { opt$zero_grad(); L <- loss_fn(); L$backward(); opt$step() }
  }
  f <- function(x) if (is.finite(x)) sprintf("%.4g", x) else "NaN"
  plain1 <- loss_fn()$item()
  nested <- with_no_grad(with_enable_grad(loss_fn()$item()))
  local_ctx <- (function() { local_no_grad(); with_enable_grad(loss_fn()$item()) })()
  plain2 <- loss_fn()$item()
  params_ok <- all(vapply(net$parameters, function(p) as.logical(torch_isfinite(p)$all()$item()), TRUE))
  paste("plain", f(plain1), "| no_grad+enable_grad", f(nested),
        "| local_no_grad+enable_grad", f(local_ctx), "| plain again", f(plain2),
        "| weights finite", params_ok)
}

N <- 4
cases <- expand.grid(dtype = c("float64", "float32"), deriv = c(TRUE, FALSE),
                     train = c(TRUE, FALSE), stringsAsFactors = FALSE)
for (k in seq_len(nrow(cases))) {
  cs <- cases[k, ]
  cat(sprintf("%s, %s, %s:\n", cs$dtype,
              if (cs$deriv) "loss with derivative" else "loss without derivative",
              if (cs$train) "after 100 Adam steps" else "untrained"))
  for (i in seq_len(N)) cat("  ", r(probe, args = list(cs$dtype, cs$deriv, cs$train)), "\n")
}
