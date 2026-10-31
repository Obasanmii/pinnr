#' pinnr: Physics-Informed Neural Networks in Native R
#'
#' `pinnr` trains neural networks whose outputs satisfy a differential
#' equation. A network \eqn{u_\theta(x)} is fitted by minimising a weighted
#' sum of
#' * the mean squared equation residual at collocation points inside the
#'   domain,
#' * the mean squared violation of boundary and initial conditions, and
#' * the mean squared misfit to observed data, when data are supplied.
#'
#' Unknown constants in the equation can be estimated jointly with the
#' network weights, which turns the same machinery into a tool for
#' parameter discovery (an inverse problem).
#'
#' The main entry points are:
#' * [pinn_ode()] builds a problem from a `deSolve`-style derivative function.
#' * [pinn_problem()] builds a problem for any partial differential equation
#'   on a rectangular domain defined with [pinn_domain()], with conditions
#'   from [pinn_dirichlet()], [pinn_neumann()], [pinn_initial()] and
#'   [pinn_condition()].
#' * [pinn_fit()] trains the network.
#' * [predict()][predict.pinn_fit()], [coef()][coef.pinn_fit()],
#'   [residuals()][residuals.pinn_fit()] and [plot()][plot.pinn_fit()]
#'   inspect the result.
#'
#' @references Raissi, M., Perdikaris, P. and Karniadakis, G. E. (2019).
#'   Physics-informed neural networks: A deep learning framework for solving
#'   forward and inverse problems involving nonlinear partial differential
#'   equations. *Journal of Computational Physics*, 378, 686-707.
#'   \doi{10.1016/j.jcp.2018.10.045}
#'
#' @import torch
#' @importFrom stats predict coef residuals runif setNames
#' @importFrom utils tail
#' @keywords internal
"_PACKAGE"

.onLoad <- function(libname, pkgname) {
  # From R 4.3.0, chooseOpsMethod() lets a single-state ODE written as
  # `r * y * (1 - y / K)` combine a pinn_state with a torch tensor without
  # an "Incompatible methods" fallback.
  if (getRversion() >= "4.3.0") {
    registerS3method("chooseOpsMethod", "pinn_state",
                     chooseOpsMethod_pinn_state)
  }
  invisible()
}

chooseOpsMethod_pinn_state <- function(x, y, mx, my, cl, reverse) TRUE
