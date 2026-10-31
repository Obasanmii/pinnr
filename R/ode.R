#' Build a problem from a deSolve-style ODE model
#'
#' Turns an ordinary differential equation written for
#' [deSolve::ode()] into a [pinn_problem()]. The same derivative function
#' can be used to solve the system (a forward problem) or, with `unknown`
#' and `data`, to estimate its parameters from observations.
#'
#' @section Writing the model: `func` has the usual `deSolve` signature
#'   `function(t, y, parms)` and returns a list whose first element holds
#'   the derivatives, in the order of `y0`. The recommended style works
#'   unchanged:
#'
#'   ```
#'   function(t, y, parms) {
#'     with(as.list(c(y, parms)), {
#'       dS <- -beta * S * I
#'       ...
#'       list(c(dS, dI, dR))
#'     })
#'   }
#'   ```
#'
#'   Indexing with `y["S"]`, `y[1]` or `parms["beta"]` also works. Because
#'   the states are torch tensors, the body must use arithmetic and maths
#'   functions; `if`, `ifelse`, `max` and `pmin` on states do not work.
#'   Forcing functions of time can be written with tensor operations, for
#'   example `torch_sin(t)` or `sin(t)`.
#'
#' @section Initial conditions: By default the initial state is enforced
#'   exactly by writing each state as
#'   \eqn{y(t) = y_0 + \frac{t - t_0}{t_1 - t_0} N(t)}, where \eqn{N} is the
#'   network. This removes one loss term and usually speeds up training.
#'   Set `hard_initial = FALSE` to use a soft penalty instead.
#'
#' @param func A derivative function `function(t, y, parms)` in `deSolve`
#'   style. See *Writing the model*.
#' @param y0 Named numeric vector of initial states at the first time.
#' @param times Numeric vector of times. Only its range is used for
#'   training; the full vector becomes the default grid for [predict()].
#' @param parms Named numeric vector or list of known parameters.
#' @param unknown Named numeric vector of initial guesses for parameters to
#'   estimate. These are passed to `func` alongside `parms`.
#' @param positive Logical; see [pinn_problem()].
#' @param data Optional data frame of observations with a column named as
#'   `time` and one column per observed state. The output of
#'   [deSolve::ode()] converted with [as.data.frame()] works directly.
#' @param time Name of the time variable. The default, `"time"`, matches the
#'   column name in `deSolve` output.
#' @param hard_initial Logical; enforce the initial state exactly. See
#'   *Initial conditions*.
#' @return A [pinn_problem()] object.
#' @examples
#' # Logistic growth dN/dt = r N (1 - N / K)
#' logistic <- function(t, y, parms) {
#'   with(as.list(c(y, parms)), list(r * N * (1 - N / K)))
#' }
#' prob <- pinn_ode(logistic, y0 = c(N = 0.1), times = seq(0, 10, by = 0.5),
#'                  parms = c(r = 1, K = 1))
#' prob
#' @export
pinn_ode <- function(func, y0, times, parms = NULL, unknown = NULL,
                     positive = TRUE, data = NULL, time = "time",
                     hard_initial = TRUE) {
  if (!is.function(func)) stop("`func` must be a function.", call. = FALSE)
  if (!is.numeric(y0) || length(y0) == 0 || any(!is.finite(y0))) {
    stop("`y0` must be a named numeric vector of initial states.", call. = FALSE)
  }
  check_names(y0, "state")
  if (!is.numeric(times) || length(times) < 2 || any(!is.finite(times))) {
    stop("`times` must be a numeric vector with at least two values.",
         call. = FALSE)
  }
  rng <- range(times)
  if (rng[1] == rng[2]) stop("`times` must span a non-zero interval.", call. = FALSE)
  if (!is.character(time) || length(time) != 1) {
    stop("`time` must be a single variable name.", call. = FALSE)
  }
  states <- names(y0)
  parms <- if (is.null(parms)) list() else as.list(parms)
  unknown_names <- names(unknown)

  residual <- function(...) {
    pool <- list(...)
    tt <- pool[[time]]
    y <- new_state(pool[states])
    pr <- new_state(c(pool[names(parms)], pool[unknown_names]))
    out <- func(tt, y, pr)
    dy <- ode_derivatives(out, states)
    lapply(seq_along(states), function(i) {
      pool$d(pool[[states[i]]], tt) - dy[[i]]
    })
  }

  conditions <- list()
  transform <- NULL
  if (isTRUE(hard_initial)) {
    t0 <- rng[1]
    span <- rng[2] - rng[1]
    transform <- function(...) {
      pool <- list(...)
      s <- (pool[[time]] - t0) / span
      out <- lapply(states, function(k) y0[[k]] + s * pool[[k]])
      stats::setNames(out, states)
    }
  } else {
    conditions <- list(pinn_initial(as.list(y0), time = time, n = 1))
  }

  domain <- do.call(pinn_domain, stats::setNames(list(rng), time))
  prob <- pinn_problem(domain = domain, outputs = states, residual = residual,
                       conditions = conditions, data = data, parms = parms,
                       unknown = unknown, positive = positive,
                       transform = transform)
  prob$meta <- list(type = "ode", times = sort(unique(times)), y0 = y0,
                    func = func, time = time, hard_initial = isTRUE(hard_initial))
  prob
}

# Extract the derivative list from what a deSolve-style function returned.
ode_derivatives <- function(out, states) {
  n <- length(states)
  bad <- function() {
    stop(sprintf(
      "The ODE function must return list(c(%s)), with one derivative per state.",
      paste0("d", states, collapse = ", ")
    ), call. = FALSE)
  }
  if (is_tensor(out)) out <- list(out)
  if (!is.list(out) || length(out) == 0) bad()
  dy <- out[[1]]
  if (is_tensor(dy)) {
    if (n == 1) return(list(dy))
    # a single tensor with one column per state
    if (length(dy$shape) == 2 && dy$shape[2] == n) {
      return(lapply(seq_len(n), function(i) dy[, i, drop = FALSE]))
    }
    bad()
  }
  if (is.numeric(dy)) dy <- as.list(rep_len(dy, n))
  if (!is.list(dy) || length(dy) != n) bad()
  dy
}

# A list of tensors that behaves like a deSolve state vector:
# y["S"] and y[1] return the element itself, and a one-state vector can be
# used directly in arithmetic.
new_state <- function(x) structure(x, class = "pinn_state")

#' @export
`[.pinn_state` <- function(x, i) {
  y <- unclass(x)[i]
  if (length(y) == 1) y[[1]] else new_state(y)
}

#' @export
as.list.pinn_state <- function(x, ...) unclass(x)

#' @export
Ops.pinn_state <- function(e1, e2) {
  unwrap <- function(e) {
    if (inherits(e, "pinn_state")) {
      if (length(e) != 1) {
        stop("Arithmetic on the whole state vector is only possible for one-state models; use with(as.list(c(y, parms)), ...) instead.",
             call. = FALSE)
      }
      e <- unclass(e)[[1]]
    }
    e
  }
  if (missing(e2)) return(get(.Generic)(unwrap(e1)))
  get(.Generic)(unwrap(e1), unwrap(e2))
}

#' @export
Math.pinn_state <- function(x, ...) {
  if (length(x) != 1) {
    stop("Maths functions on the whole state vector need a one-state model.",
         call. = FALSE)
  }
  get(.Generic)(unclass(x)[[1]], ...)
}
