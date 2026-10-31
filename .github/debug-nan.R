# Diagnose the NaN in test-fit.R "optional training modes run" on macOS arm64.
# Round 1 showed the failure only on the FIRST fit in a fresh R session, so
# every run here gets its own fresh R process (callr), repeated several times.
library(callr)
cat("Host:", R.version$platform, "\n")
cat(r(function() paste("torch", packageVersion("torch"),
                       "| threads", torch::torch_get_num_threads())), "\n\n")

N <- 6  # fresh sessions per variant

# --- pinnr, one fit per fresh session -------------------------------------
fit_once <- function(args, threads) {
  library(pinnr)
  if (!is.null(threads)) torch::torch_set_num_threads(threads)
  decay <- function(t, y, parms) list(-parms["k"] * y)
  prob <- pinn_ode(decay, y0 = c(y = 1), times = c(0, 2), parms = c(k = 1))
  base <- list(hidden = c(8, 8), epochs = 100, lbfgs_iter = 20,
               precision = "float64", resample_every = 25,
               sampling = "uniform", activation = "sin", seed = 1,
               verbose = FALSE)
  res <- tryCatch(suppressWarnings(do.call(pinn_fit, c(list(prob), modifyList(base, args)))),
                  error = function(e) e)
  if (inherits(res, "error")) "NaN" else sprintf("%.3g", res$final_loss[["total"]])
}

variants <- list(
  "as in test"        = list(args = list(), threads = NULL),
  "1 thread"          = list(args = list(), threads = 1L),
  "float32"           = list(args = list(precision = "float32"), threads = NULL),
  "no L-BFGS"         = list(args = list(lbfgs_iter = 0), threads = NULL),
  "no resampling"     = list(args = list(resample_every = 0), threads = NULL),
  "tanh"              = list(args = list(activation = "tanh"), threads = NULL)
)

cat(sprintf("pinnr, %d fresh sessions each:\n", N))
for (nm in names(variants)) {
  v <- variants[[nm]]
  out <- vapply(seq_len(N), function(i) r(fit_once, args = list(v$args, v$threads)), "")
  cat(sprintf("  %-15s NaN in %d/%d   [%s]\n", nm, sum(out == "NaN"), N,
              paste(out, collapse = " ")))
}

# --- the same computation in plain torch, no pinnr ---------------------------
plain_torch <- function(threads) {
  library(torch)
  if (!is.null(threads)) torch_set_num_threads(threads)
  set.seed(1); torch_manual_seed(1)
  dt <- torch_float64()
  lin <- function(i, o) { l <- nn_linear(i, o); nn_init_xavier_normal_(l$weight); nn_init_zeros_(l$bias); l }
  sine <- nn_module(forward = function(x) torch_sin(x))
  net <- nn_sequential(lin(1, 8), sine(), lin(8, 8), sine(), lin(8, 1))
  net$to(dtype = dt)
  pts <- function() torch_tensor(matrix(runif(1000, 0, 2), ncol = 1), dtype = dt, requires_grad = TRUE)
  loss_fn <- function(t) {
    u <- net(t - 1)                       # map [0, 2] to [-1, 1]
    y <- 1 + (t / 2) * u                  # exact initial condition y(0) = 1
    dy <- autograd_grad(list(y), list(t), list(torch_ones_like(y)), create_graph = TRUE)[[1]]
    (dy + y)$pow(2)$mean()                # dy/dt = -y
  }
  t <- pts()
  opt <- optim_adam(net$parameters, lr = 1e-3)
  for (ep in 1:100) {
    if (ep > 1 && (ep - 1) %% 25 == 0) t <- pts()
    opt$zero_grad(); L <- loss_fn(t); L$backward(); opt$step()
  }
  adam_loss <- loss_fn(t)$item()
  lb <- optim_lbfgs(net$parameters, lr = 1, max_iter = 20, tolerance_grad = 1e-9,
                    tolerance_change = 1e-12, history_size = 50,
                    line_search_fn = "strong_wolfe")
  first_nan <- NA_integer_; n <- 0L
  closure <- function() {
    lb$zero_grad(); L <- loss_fn(t); L$backward(); n <<- n + 1L
    if (is.na(first_nan) && !is.finite(L$item())) first_nan <<- n
    L
  }
  try(lb$step(closure), silent = TRUE)
  sprintf("adam %.3g, lbfgs %s", adam_loss,
          if (is.na(first_nan)) sprintf("ok %.3g", loss_fn(t)$item()) else paste0("NaN@eval", first_nan))
}

cat(sprintf("\nPlain torch (no pinnr), %d fresh sessions each:\n", N))
for (th in list(NULL, 1L)) {
  out <- vapply(seq_len(N), function(i) r(plain_torch, args = list(th)), "")
  cat(sprintf("  threads %-7s NaN in %d/%d\n", if (is.null(th)) "default" else th,
              sum(grepl("NaN", out)), N))
  cat(paste0("    ", out, collapse = "\n"), "\n")
}
