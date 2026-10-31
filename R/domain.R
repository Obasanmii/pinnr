#' Define a rectangular domain
#'
#' Each argument names an input variable of the problem and gives its range
#' as `c(lower, upper)`. The order of the arguments is the order in which
#' the variables enter the network.
#'
#' @param ... Named numeric vectors of length 2, for example
#'   `x = c(0, 1), t = c(0, 10)`.
#' @return An object of class `pinn_domain`.
#' @examples
#' pinn_domain(x = c(-1, 1), t = c(0, 1))
#' @export
pinn_domain <- function(...) {
  b <- list(...)
  if (length(b) == 0) {
    stop("A domain needs at least one variable, e.g. pinn_domain(t = c(0, 1)).",
         call. = FALSE)
  }
  check_names(b, "domain variable")
  for (nm in names(b)) {
    r <- b[[nm]]
    if (!is.numeric(r) || length(r) != 2 || any(!is.finite(r))) {
      stop(sprintf("Domain variable `%s` must be a finite numeric range c(lower, upper).",
                   nm), call. = FALSE)
    }
    if (r[1] >= r[2]) {
      stop(sprintf("Domain variable `%s`: lower bound must be below upper bound.",
                   nm), call. = FALSE)
    }
  }
  structure(
    list(
      vars = names(b),
      lower = vapply(b, function(r) as.numeric(r[1]), numeric(1)),
      upper = vapply(b, function(r) as.numeric(r[2]), numeric(1))
    ),
    class = "pinn_domain"
  )
}

as_pinn_domain <- function(x) {
  if (inherits(x, "pinn_domain")) return(x)
  if (is.list(x)) return(do.call(pinn_domain, x))
  stop("`domain` must be created with pinn_domain() or be a named list of ranges.",
       call. = FALSE)
}

#' @export
print.pinn_domain <- function(x, ...) {
  cat("<pinn_domain>\n")
  for (v in x$vars) {
    cat(sprintf("  %s in [%s, %s]\n", v, fmt_num(x$lower[[v]]),
                fmt_num(x$upper[[v]])))
  }
  invisible(x)
}
