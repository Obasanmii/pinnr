#' Define a physics-informed problem
#'
#' Collects everything a PINN needs: the domain, the names of the unknown
#' functions, the equation residual, conditions, optional observations and
#' the equation's parameters.
#'
#' @section Writing the residual: `residual` is an R function whose
#'   arguments are matched **by name** to:
#'   * the outputs (for example `u`),
#'   * the domain variables (for example `x`, `t`),
#'   * the parameters in `parms` and `unknown`, and
#'   * `d`, the derivative operator.
#'
#'   `d(f, x)` differentiates `f` with respect to the variable `x`;
#'   `d(f, x, x)` gives the second derivative and `d(f, x, t)` a mixed
#'   derivative. The function returns the expression that should equal
#'   zero, or a list of such expressions for a system of equations. For
#'   the viscous Burgers equation \eqn{u_t + u u_x - \nu u_{xx} = 0}:
#'
#'   ```
#'   function(u, x, t, nu, d) d(u, t) + u * d(u, x) - nu * d(u, x, x)
#'   ```
#'
#'   All arguments are torch tensors with one row per point, so use
#'   arithmetic and maths functions (`sin`, `exp`, `log`, `sqrt`, ...)
#'   and avoid `if`, `ifelse` or functions that leave R's torch methods.
#'
#' @section Output transforms: `transform` can enforce conditions exactly
#'   ("hard constraints"). It is called with the raw network outputs,
#'   domain variables and parameters (matched by name, as above) and
#'   returns a named list of modified outputs. For example, to make
#'   \eqn{u(0, t) = u(1, t) = 0} hold exactly:
#'   `transform = function(u, x) list(u = x * (1 - x) * u)`.
#'
#' @param domain A [pinn_domain()], or a named list of ranges.
#' @param outputs Character vector naming the unknown functions.
#' @param residual Function returning the equation residual. See *Writing
#'   the residual*.
#' @param conditions A condition or list of conditions from
#'   [pinn_dirichlet()], [pinn_neumann()], [pinn_initial()] or
#'   [pinn_condition()].
#' @param data Optional data frame of observations, with one column per
#'   domain variable and one column for each observed output. Missing
#'   values (`NA`) are ignored, so outputs can be observed at different
#'   points.
#' @param parms Named list or numeric vector of known constants.
#' @param unknown Named numeric vector of initial guesses for parameters to
#'   estimate.
#' @param positive Logical, recycled or named by `unknown`. Positive
#'   parameters are estimated on the log scale, which keeps them positive
#'   and usually helps convergence.
#' @param transform Optional output transform. See *Output transforms*.
#' @return An object of class `pinn_problem`.
#' @seealso [pinn_ode()] for ordinary differential equations written in
#'   `deSolve` style, and [pinn_fit()] to train the network.
#' @examples
#' # Heat equation u_t = a u_xx with u(x, 0) = sin(pi x) and u = 0 at both ends
#' heat <- pinn_problem(
#'   domain = pinn_domain(x = c(0, 1), t = c(0, 1)),
#'   outputs = "u",
#'   residual = function(u, x, t, a, d) d(u, t) - a * d(u, x, x),
#'   conditions = list(
#'     pinn_initial(function(x) sin(pi * x), time = "t"),
#'     pinn_dirichlet(where = list(x = "both"), value = 0)
#'   ),
#'   parms = list(a = 0.1)
#' )
#' heat
#' @export
pinn_problem <- function(domain, outputs, residual, conditions = list(),
                         data = NULL, parms = list(), unknown = NULL,
                         positive = TRUE, transform = NULL) {
  domain <- as_pinn_domain(domain)

  if (!is.character(outputs) || length(outputs) == 0) {
    stop("`outputs` must be a character vector of output names.", call. = FALSE)
  }
  check_names(stats::setNames(outputs, outputs), "output")
  if (!is.function(residual)) {
    stop("`residual` must be a function.", call. = FALSE)
  }
  if (!is.null(transform) && !is.function(transform)) {
    stop("`transform` must be a function or NULL.", call. = FALSE)
  }

  if (is.numeric(parms)) parms <- as.list(parms)
  if (!is.list(parms)) {
    stop("`parms` must be a named list or numeric vector.", call. = FALSE)
  }
  check_names(parms, "parameter")
  for (nm in names(parms)) {
    if (!is.numeric(parms[[nm]])) {
      stop(sprintf("Parameter `%s` must be numeric.", nm), call. = FALSE)
    }
  }

  unknown <- check_unknown(unknown, positive)

  all_names <- c(domain$vars, outputs, names(parms), names(unknown$init))
  if (anyDuplicated(all_names)) {
    stop(sprintf(
      "Names must be unique across domain variables, outputs and parameters (clash: %s).",
      paste(unique(all_names[duplicated(all_names)]), collapse = ", ")
    ), call. = FALSE)
  }

  if (inherits(conditions, "pinn_condition")) conditions <- list(conditions)
  if (!is.list(conditions) ||
      !all(vapply(conditions, inherits, logical(1), "pinn_condition"))) {
    stop("`conditions` must be a list of objects made by pinn_dirichlet(), pinn_neumann(), pinn_initial() or pinn_condition().",
         call. = FALSE)
  }
  resolved <- lapply(seq_along(conditions), function(i) {
    resolve_condition(conditions[[i]], domain, outputs, i)
  })

  data <- check_data(data, domain, outputs)

  if (length(resolved) == 0 && is.null(data) && is.null(transform)) {
    warning("The problem has no conditions, data or transform, so its solution is not unique.",
            call. = FALSE)
  }

  structure(
    list(domain = domain, outputs = outputs, residual = residual,
         conditions = resolved, data = data, parms = parms,
         unknown = unknown, transform = transform, meta = list()),
    class = "pinn_problem"
  )
}

check_unknown <- function(unknown, positive) {
  if (is.null(unknown) || length(unknown) == 0) {
    return(list(init = numeric(0), positive = logical(0)))
  }
  if (is.list(unknown)) unknown <- unlist(unknown)
  if (!is.numeric(unknown) || any(!is.finite(unknown))) {
    stop("`unknown` must be a named numeric vector of initial guesses.",
         call. = FALSE)
  }
  check_names(unknown, "unknown parameter")
  if (!is.logical(positive) || anyNA(positive)) {
    stop("`positive` must be logical.", call. = FALSE)
  }
  if (!is.null(names(positive))) {
    pos <- stats::setNames(rep(TRUE, length(unknown)), names(unknown))
    extra <- setdiff(names(positive), names(unknown))
    if (length(extra)) {
      stop(sprintf("`positive` names unknown parameter(s): %s.",
                   paste(extra, collapse = ", ")), call. = FALSE)
    }
    pos[names(positive)] <- positive
  } else {
    pos <- stats::setNames(rep_len(positive, length(unknown)), names(unknown))
  }
  if (any(unknown[pos] <= 0)) {
    stop("Initial guesses for positive unknown parameters must be > 0.",
         call. = FALSE)
  }
  list(init = unknown, positive = pos)
}

check_data <- function(data, domain, outputs) {
  if (is.null(data)) return(NULL)
  data <- as.data.frame(data)
  miss <- setdiff(domain$vars, names(data))
  if (length(miss)) {
    stop(sprintf("`data` is missing domain variable column(s): %s.",
                 paste(miss, collapse = ", ")), call. = FALSE)
  }
  obs <- intersect(outputs, names(data))
  # A column without any observation carries no information, and would
  # divide by zero in the data loss.
  obs <- obs[vapply(obs, function(o) !all(is.na(data[[o]])), logical(1))]
  if (length(obs) == 0) {
    stop("`data` must contain at least one output column with observed values.",
         call. = FALSE)
  }
  for (v in c(domain$vars, obs)) {
    if (!is.numeric(data[[v]])) {
      stop(sprintf("`data$%s` must be numeric.", v), call. = FALSE)
    }
  }
  if (anyNA(data[domain$vars])) {
    stop("`data` has missing values in domain variable columns.", call. = FALSE)
  }
  data <- data[c(domain$vars, obs)]
  data <- data[rowSums(!is.na(data[obs])) > 0, , drop = FALSE]
  if (nrow(data) == 0) stop("`data` has no observed values.", call. = FALSE)
  data
}

#' @export
print.pinn_problem <- function(x, ...) {
  cat("<pinn_problem>\n")
  cat("  Domain:     ", paste(sprintf("%s in [%s, %s]", x$domain$vars,
                                       fmt_num(x$domain$lower),
                                       fmt_num(x$domain$upper)),
                               collapse = ", "), "\n", sep = "")
  cat("  Outputs:    ", paste(x$outputs, collapse = ", "), "\n", sep = "")
  if (length(x$parms)) {
    cat("  Parameters: ", paste(sprintf("%s = %s", names(x$parms),
                                        vapply(x$parms, function(p) paste(fmt_num(p), collapse = ","), "")),
                                collapse = ", "), "\n", sep = "")
  }
  if (length(x$unknown$init)) {
    cat("  Unknown:    ", paste(sprintf("%s (start %s)", names(x$unknown$init),
                                        fmt_num(x$unknown$init)),
                                collapse = ", "), "\n", sep = "")
  }
  if (length(x$conditions)) {
    cat("  Conditions:\n")
    for (cnd in x$conditions) cat("    ", format_condition(cnd$spec), "\n", sep = "")
  }
  if (!is.null(x$transform)) cat("  Output transform: yes\n")
  if (!is.null(x$data)) {
    cat(sprintf("  Data:       %d rows observing %s\n", nrow(x$data),
                paste(intersect(x$outputs, names(x$data)), collapse = ", ")))
  }
  invisible(x)
}

# Derivative operator handed to user functions as `d`.
# d(f, x) = df/dx; d(f, x, x) = d2f/dx2; d(f, x, t) = d2f/dxdt.
pinn_d <- function(f, ...) {
  vars <- list(...)
  if (length(vars) == 0) {
    stop("d() needs at least one variable, e.g. d(u, x).", call. = FALSE)
  }
  for (v in vars) {
    if (!is_tensor(v)) {
      stop("d(f, x): `x` must be a domain variable.", call. = FALSE)
    }
    if (!is_tensor(f) || !isTRUE(f$requires_grad)) {
      # constants have zero derivative
      f <- torch_zeros_like(v)
      next
    }
    g <- autograd_grad(
      outputs = list(f), inputs = list(v),
      grad_outputs = list(torch_ones_like(f)),
      create_graph = TRUE, allow_unused = TRUE
    )[[1]]
    f <- if (is_undefined_tensor(g)) torch_zeros_like(v) else g
  }
  f
}
