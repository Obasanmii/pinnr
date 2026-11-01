# Changelog

## pinnr 0.1.1

- Fixed intermittent `NaN` or wrong losses with `precision = "float64"`.
  Coordinate and data tensors were built from one-column R matrices,
  which `torch_tensor()` does not copy for double precision, so they
  could point to memory that R had already freed. pinnr now always
  copies R data into tensors. The failure was seen most often on Apple
  Silicon Macs.
- README: Intel Macs on macOS 14 or older need torch 0.16.3 or earlier.

## pinnr 0.1.0

- First release.

- [`pinn_fit()`](https://obasanmii.github.io/pinnr/reference/pinn_fit.md)
  no longer throws away the model when the loss becomes `NaN` or
  infinite. It keeps the weights with the lowest loss seen so far,
  restores them, and returns the fit with a warning and
  `diverged = TRUE`.

- Output columns in `data` with no observed values are now dropped
  instead of making the data loss `NaN`. This could happen with
  `windows`, where each window sees only its own slice of the data.

- `plot(fit, type = "solution")` draws 1D solutions on a dense grid, so
  ODE curves are smooth even when `times` has few points.

- Window fits no longer store a copy of the whole problem in their
  `call`.

- [`pinn_sample()`](https://obasanmii.github.io/pinnr/reference/pinn_sample.md)
  (and therefore conditions) uses every combination of the fixed values
  when several variables are fixed, e.g. the four corners for
  `where = list(x = "both", y = "both")`, and gives every fixed value at
  least one point.

- Argument checks reject `NA` in `hidden` and infinite counts and rates
  with clear messages.

- [`pinn_ode()`](https://obasanmii.github.io/pinnr/reference/pinn_ode.md)
  builds problems from `deSolve`-style ODE models, with exact initial
  conditions by default.

- [`pinn_problem()`](https://obasanmii.github.io/pinnr/reference/pinn_problem.md)
  and
  [`pinn_domain()`](https://obasanmii.github.io/pinnr/reference/pinn_domain.md)
  define PDE problems on rectangular domains; residuals are R functions
  with arguments matched by name and the derivative operator `d()`.

- Conditions:
  [`pinn_dirichlet()`](https://obasanmii.github.io/pinnr/reference/conditions.md),
  [`pinn_neumann()`](https://obasanmii.github.io/pinnr/reference/conditions.md),
  [`pinn_initial()`](https://obasanmii.github.io/pinnr/reference/conditions.md)
  and
  [`pinn_condition()`](https://obasanmii.github.io/pinnr/reference/conditions.md),
  plus output transforms for hard constraints.

- Parameter estimation from partly observed, noisy data through
  `unknown` and `data`.

- [`pinn_fit()`](https://obasanmii.github.io/pinnr/reference/pinn_fit.md)
  trains with Adam and optional L-BFGS, Latin hypercube sampling,
  resampling, time marching (`windows`) for long ODE horizons, GPU
  devices and single or double precision.

- Methods [`predict()`](https://rdrr.io/r/stats/predict.html),
  [`residuals()`](https://rdrr.io/r/stats/residuals.html),
  [`coef()`](https://rdrr.io/r/stats/coef.html),
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html),
  [`summary()`](https://rdrr.io/r/base/summary.html), and
  [`pinn_save()`](https://obasanmii.github.io/pinnr/reference/pinn_save.md)
  /
  [`pinn_load()`](https://obasanmii.github.io/pinnr/reference/pinn_save.md).
