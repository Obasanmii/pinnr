skip_if_no_torch <- function() {
  testthat::skip_if_not_installed("torch")
  testthat::skip_if_not(torch::torch_is_installed(),
                        "torch backend (libtorch) is not installed")
}

# Reference solution of an ODE with a fixed-step RK4, so the tests do not
# need deSolve.
rk4 <- function(f, y0, times, parms) {
  out <- matrix(NA_real_, length(times), length(y0),
                dimnames = list(NULL, names(y0)))
  y <- y0
  out[1, ] <- y
  for (i in seq_along(times)[-1]) {
    h <- times[i] - times[i - 1]
    t <- times[i - 1]
    k1 <- f(t, y, parms)
    k2 <- f(t + h / 2, y + h / 2 * k1, parms)
    k3 <- f(t + h / 2, y + h / 2 * k2, parms)
    k4 <- f(t + h, y + h * k3, parms)
    y <- y + h / 6 * (k1 + 2 * k2 + 2 * k3 + k4)
    out[i, ] <- y
  }
  out
}
