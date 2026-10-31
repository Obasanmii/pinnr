# Diagnose the NaN in test-fit.R "optional training modes run" on macOS arm64.
# Runs the failing configuration with one setting changed at a time.
library(pinnr)
cat("torch", as.character(packageVersion("torch")), "|", R.version$platform, "\n\n")

decay <- function(t, y, parms) list(-parms["k"] * y)
prob <- pinn_ode(decay, y0 = c(y = 1), times = c(0, 2), parms = c(k = 1))

base <- list(hidden = c(8, 8), epochs = 100, lbfgs_iter = 20,
             precision = "float64", resample_every = 25,
             sampling = "uniform", activation = "sin", seed = 1,
             verbose = FALSE)
variants <- list(
  "as in test"         = list(),
  "tanh"               = list(activation = "tanh"),
  "float32"            = list(precision = "float32"),
  "no L-BFGS"          = list(lbfgs_iter = 0),
  "no resampling"      = list(resample_every = 0),
  "lhs sampling"       = list(sampling = "lhs"),
  "seed 2"             = list(seed = 2),
  "seed 3"             = list(seed = 3)
)

run <- function(args) {
  w <- NULL
  res <- withCallingHandlers(
    tryCatch(do.call(pinn_fit, c(list(prob), args)),
             error = function(e) e),
    warning = function(x) { w <<- conditionMessage(x); invokeRestart("muffleWarning") })
  if (inherits(res, "error")) {
    sprintf("ERROR    %s", conditionMessage(res))
  } else {
    h <- res$history
    sprintf("ok       final loss %.3g | diverged %s | lbfgs records %d%s",
            res$final_loss[["total"]], res$diverged, sum(h$phase == "lbfgs"),
            if (!is.null(w)) paste(" | warning:", w) else "")
  }
}

for (nm in names(variants)) {
  args <- modifyList(base, variants[[nm]])
  cat(sprintf("%-16s %s\n", nm, run(args)))
}

# Same failing run twice: is it deterministic?
cat("\nRepeat of the test configuration:\n")
for (i in 1:2) cat(" ", run(base), "\n")

# Loss trace of the Adam phase, recorded every step
cat("\nAdam-only trace (every step, last 15):\n")
fit <- tryCatch(do.call(pinn_fit, c(list(prob), modifyList(base, list(lbfgs_iter = 0, record_every = 1)))),
                error = function(e) e)
if (inherits(fit, "error")) print(conditionMessage(fit)) else print(utils::tail(fit$history[, c("step", "phase", "total", "residual")], 15))
