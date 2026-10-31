#' Boundary, initial and custom conditions
#'
#' Conditions are enforced as soft penalties on points sampled where they
#' apply. Each condition fixes one or more domain variables (`where`) and
#' samples the remaining variables over their full range.
#'
#' * `pinn_dirichlet()` fixes the value of the solution, \eqn{u = g}.
#' * `pinn_neumann()` fixes a first derivative, \eqn{\partial u / \partial
#'   v = g}.
#' * `pinn_initial()` is a Dirichlet condition at the lower end of the time
#'   variable.
#' * `pinn_condition()` takes any residual function, for Robin, periodic
#'   or other conditions.
#'
#' @section Locations: Each element of `where` is a number or one of the
#'   strings `"lower"`, `"upper"` or `"both"`, which refer to the ends of
#'   that variable's range. `where = list(x = "both")` places points on both
#'   ends of `x`. When several variables are fixed, every combination of
#'   their values is used: `where = list(x = "both", y = "both")` places
#'   points on the four corners.
#'
#' @section Values: `value` can be a number, a numeric vector named by
#'   output, or a function. A function's arguments are matched by name to
#'   the domain variables, outputs and parameters, so
#'   `value = function(x) sin(pi * x)` uses the spatial variable `x`.
#'   Inside these functions the arguments are torch tensors, so use
#'   arithmetic and maths functions (`sin`, `exp`, `log`, ...) rather than
#'   control flow such as `if` or `ifelse`.
#'
#' @param where Named list giving the fixed value(s) of one or more domain
#'   variables. See *Locations*.
#' @param value Target value. See *Values*.
#' @param output Name(s) of the output(s) the condition applies to. The
#'   default `NULL` applies it to every output.
#' @param along Name of the domain variable to differentiate with respect to.
#' @param time Name of the time variable for `pinn_initial()`.
#' @param fn For `pinn_condition()`, a function returning the residual (a
#'   tensor, or a list of tensors) that should be zero. Arguments are
#'   matched by name to outputs, domain variables, parameters and the
#'   derivative operator `d` (see [pinn_problem()]).
#' @param n Number of points used for this condition.
#' @param weight Relative weight of this condition in the loss.
#' @param name Optional label used in printed output.
#' @return An object of class `pinn_condition`.
#' @examples
#' # u = 0 on both ends of x
#' pinn_dirichlet(where = list(x = "both"), value = 0)
#'
#' # u(x, 0) = sin(pi x)
#' pinn_initial(function(x) sin(pi * x), time = "t")
#'
#' # insulated right boundary: du/dx = 0 at x = 1
#' pinn_neumann(where = list(x = "upper"), along = "x")
#'
#' # Robin condition du/dx + 2 u = 0 at x = 1, as a custom residual
#' pinn_condition(where = list(x = "upper"),
#'                fn = function(u, x, d) d(u, x) + 2 * u)
#' @name conditions
NULL

new_condition <- function(where, type, n, weight, name, ...) {
  if (!is.list(where)) {
    stop("`where` must be a named list, e.g. list(x = 0).", call. = FALSE)
  }
  if (length(where)) check_names(where, "`where`")
  for (nm in names(where)) {
    w <- where[[nm]]
    ok <- (is.numeric(w) && length(w) >= 1 && all(is.finite(w))) ||
      (is.character(w) && length(w) == 1 && w %in% c("lower", "upper", "both"))
    if (!ok) {
      stop(sprintf(
        "`where$%s` must be numeric or one of \"lower\", \"upper\", \"both\".",
        nm), call. = FALSE)
    }
  }
  structure(
    list(where = where, type = type, n = check_count(n, "n"),
         weight = check_positive(weight, "weight"), name = name, ...),
    class = "pinn_condition"
  )
}

#' @rdname conditions
#' @export
pinn_dirichlet <- function(where, value = 0, output = NULL, n = 100,
                           weight = 1, name = NULL) {
  check_value(value)
  new_condition(where, "dirichlet", n, weight, name,
                value = value, output = output)
}

#' @rdname conditions
#' @export
pinn_neumann <- function(where, along, value = 0, output = NULL, n = 100,
                         weight = 1, name = NULL) {
  if (!is.character(along) || length(along) != 1) {
    stop("`along` must be the name of one domain variable.", call. = FALSE)
  }
  check_value(value)
  new_condition(where, "neumann", n, weight, name,
                value = value, output = output, along = along)
}

#' @rdname conditions
#' @export
pinn_initial <- function(value, time = "t", output = NULL, n = 100,
                         weight = 1, name = NULL) {
  if (!is.character(time) || length(time) != 1) {
    stop("`time` must be the name of the time variable.", call. = FALSE)
  }
  check_value(value)
  new_condition(stats::setNames(list("lower"), time), "dirichlet", n, weight,
                name %||% "initial", value = value, output = output)
}

#' @rdname conditions
#' @export
pinn_condition <- function(where, fn, n = 100, weight = 1, name = NULL) {
  if (!is.function(fn)) stop("`fn` must be a function.", call. = FALSE)
  new_condition(where, "custom", n, weight, name, fn = fn)
}

check_value <- function(value) {
  ok <- is.function(value) || (is.numeric(value) && all(is.finite(value))) ||
    (is.list(value) && length(value) > 0 &&
       all(vapply(value, function(v) is.function(v) ||
                    (is.numeric(v) && length(v) == 1), logical(1))))
  if (!ok) {
    stop("`value` must be a number, a numeric vector, a function, or a list of these.",
         call. = FALSE)
  }
  invisible(value)
}

#' @export
print.pinn_condition <- function(x, ...) {
  cat(format_condition(x), "\n", sep = "")
  invisible(x)
}

format_condition <- function(x) {
  where <- if (length(x$where)) {
    paste(vapply(names(x$where), function(v) {
      w <- x$where[[v]]
      sprintf("%s = %s", v, if (is.numeric(w)) paste(fmt_num(w), collapse = "|") else w)
    }, character(1)), collapse = ", ")
  } else {
    "interior"
  }
  label <- x$name %||% x$type
  sprintf("<pinn_condition: %s at %s, n = %d>", label, where, x$n)
}

# Turn "lower"/"upper"/"both" into numbers and check they lie in the domain.
resolve_where <- function(where, domain) {
  bad <- setdiff(names(where), domain$vars)
  if (length(bad)) {
    stop(sprintf("Condition refers to unknown domain variable(s): %s.",
                 paste(bad, collapse = ", ")), call. = FALSE)
  }
  out <- lapply(names(where), function(v) {
    w <- where[[v]]
    lo <- domain$lower[[v]]
    hi <- domain$upper[[v]]
    if (is.character(w)) {
      w <- switch(w, lower = lo, upper = hi, both = c(lo, hi))
    }
    if (any(w < lo - 1e-12 * abs(lo) | w > hi + 1e-12 * abs(hi))) {
      stop(sprintf("Condition location for `%s` lies outside the domain [%s, %s].",
                   v, fmt_num(lo), fmt_num(hi)), call. = FALSE)
    }
    w
  })
  stats::setNames(out, names(where))
}

# Value for output `o` (position `i`) given the pool of tensors.
condition_value <- function(value, o, i, n_out, pool) {
  v <- value
  if (is.list(value) && !is.function(value)) {
    v <- if (!is.null(names(value))) value[[o]] else value[[i]]
  } else if (is.numeric(value) && length(value) > 1) {
    v <- if (!is.null(names(value))) value[[o]] else value[[i]]
  }
  if (is.null(v)) {
    stop(sprintf("No condition value given for output `%s`.", o), call. = FALSE)
  }
  if (is.function(v)) v <- call_with_pool(v, pool, "A condition `value` function")
  v
}

# Convert a condition spec into the internal form used during training.
resolve_condition <- function(cond, domain, outputs, index) {
  where <- resolve_where(cond$where, domain)
  label <- cond$name %||% sprintf("%s_%d", cond$type, index)
  if (cond$type %in% c("dirichlet", "neumann")) {
    outs <- cond$output %||% outputs
    bad <- setdiff(outs, outputs)
    if (length(bad)) {
      stop(sprintf("Condition refers to unknown output(s): %s.",
                   paste(bad, collapse = ", ")), call. = FALSE)
    }
    v <- cond$value
    if (is.numeric(v) && length(v) > 1 && is.null(names(v)) &&
        length(v) != length(outs)) {
      stop("An unnamed `value` vector must have one entry per output.",
           call. = FALSE)
    }
  }
  if (cond$type == "neumann" && !cond$along %in% domain$vars) {
    stop(sprintf("`along = \"%s\"` is not a domain variable.", cond$along),
         call. = FALSE)
  }
  fn <- switch(
    cond$type,
    dirichlet = function(pool) {
      lapply(seq_along(outs), function(i) {
        pool[[outs[i]]] - condition_value(v, outs[i], i, length(outs), pool)
      })
    },
    neumann = function(pool) {
      lapply(seq_along(outs), function(i) {
        pool$d(pool[[outs[i]]], pool[[cond$along]]) -
          condition_value(v, outs[i], i, length(outs), pool)
      })
    },
    custom = function(pool) {
      as_residual_list(call_with_pool(cond$fn, pool, "A condition `fn`"),
                       "A condition `fn`")
    }
  )
  list(where = where, n = cond$n, weight = cond$weight, name = label, fn = fn,
       spec = cond)
}
