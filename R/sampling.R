#' Sample points in a domain
#'
#' Draws training points uniformly at random or with Latin hypercube
#' sampling. Variables listed in `fixed` are held at the given values, which
#' is how boundary and initial points are generated.
#'
#' @param n Number of points.
#' @param domain A [pinn_domain()].
#' @param method `"lhs"` (Latin hypercube, the default) or `"uniform"`.
#' @param fixed Named list of numeric values. When a variable has several
#'   values, the points are split evenly between them. With several fixed
#'   variables, every combination of their values is used, so
#'   `list(x = c(0, 1), y = c(0, 1))` gives the four corners. Each value
#'   (or combination) gets at least one point, so the result can have more
#'   than `n` rows when `n` is smaller than the number of combinations.
#' @return A data frame with one column per domain variable.
#' @examples
#' dom <- pinn_domain(x = c(0, 1), t = c(0, 2))
#' head(pinn_sample(5, dom))
#' pinn_sample(4, dom, fixed = list(x = c(0, 1)))
#' @export
pinn_sample <- function(n, domain, method = c("lhs", "uniform"),
                        fixed = list()) {
  n <- check_count(n, "n")
  domain <- as_pinn_domain(domain)
  method <- match.arg(method)
  bad <- setdiff(names(fixed), domain$vars)
  if (length(bad)) {
    stop(sprintf("Unknown variable(s) in `fixed`: %s.", paste(bad, collapse = ", ")),
         call. = FALSE)
  }
  fixed_vars <- intersect(domain$vars, names(fixed))
  combos <- expand.grid(fixed[fixed_vars], KEEP.OUT.ATTRS = FALSE)
  k <- if (length(fixed_vars)) nrow(combos) else 1L
  n <- max(n, k)
  # blocks of equal size, so each combination gets ~n / k points (at least 1)
  block <- rep(seq_len(k), times = diff(c(0, round(seq_len(k) * n / k))))
  out <- lapply(domain$vars, function(v) {
    if (v %in% fixed_vars) {
      combos[[v]][block]
    } else {
      lo <- domain$lower[[v]]
      hi <- domain$upper[[v]]
      u <- if (method == "lhs") (sample.int(n) - runif(n)) / n else runif(n)
      lo + u * (hi - lo)
    }
  })
  names(out) <- domain$vars
  as.data.frame(out)
}
