# pinnr 0.1.0

* First release.

* `pinn_fit()` no longer throws away the model when the loss becomes `NaN`
  or infinite. It keeps the weights with the lowest loss seen so far,
  restores them, and returns the fit with a warning and `diverged = TRUE`.
* Output columns in `data` with no observed values are now dropped instead
  of making the data loss `NaN`. This could happen with `windows`, where
  each window sees only its own slice of the data.
* `plot(fit, type = "solution")` draws 1D solutions on a dense grid, so ODE
  curves are smooth even when `times` has few points.
* Window fits no longer store a copy of the whole problem in their `call`.
* `pinn_sample()` (and therefore conditions) uses every combination of the
  fixed values when several variables are fixed, e.g. the four corners for
  `where = list(x = "both", y = "both")`, and gives every fixed value at
  least one point.
* Argument checks reject `NA` in `hidden` and infinite counts and rates
  with clear messages.


* `pinn_ode()` builds problems from `deSolve`-style ODE models, with exact
  initial conditions by default.
* `pinn_problem()` and `pinn_domain()` define PDE problems on rectangular
  domains; residuals are R functions with arguments matched by name and
  the derivative operator `d()`.
* Conditions: `pinn_dirichlet()`, `pinn_neumann()`, `pinn_initial()` and
  `pinn_condition()`, plus output transforms for hard constraints.
* Parameter estimation from partly observed, noisy data through `unknown`
  and `data`.
* `pinn_fit()` trains with Adam and optional L-BFGS, Latin hypercube
  sampling, resampling, time marching (`windows`) for long ODE horizons,
  GPU devices and single or double precision.
* Methods `predict()`, `residuals()`, `coef()`, `plot()`, `summary()`, and
  `pinn_save()` / `pinn_load()`.
