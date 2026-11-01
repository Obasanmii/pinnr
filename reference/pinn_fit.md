# Train a physics-informed neural network

Fits a fully connected network to a
[`pinn_problem()`](https://obasanmii.github.io/pinnr/reference/pinn_problem.md)
(or a problem from
[`pinn_ode()`](https://obasanmii.github.io/pinnr/reference/pinn_ode.md))
by minimising \$\$w_r L\_{residual} + w_c L\_{conditions} + w_d
L\_{data},\$\$ where each term is a mean squared error. Training runs
`epochs` steps of Adam and then, optionally, `lbfgs_iter` iterations of
L-BFGS, which often sharpens the solution considerably.

## Usage

``` r
pinn_fit(
  problem,
  hidden = c(32, 32, 32),
  activation = "tanh",
  epochs = 5000,
  lr = 0.001,
  lr_unknown = NULL,
  lbfgs_iter = 0,
  n_collocation = 1000,
  sampling = c("lhs", "uniform"),
  resample_every = 0,
  weights = c(residual = 1, conditions = 1, data = 1),
  precision = c("float32", "float64"),
  device = "cpu",
  seed = NULL,
  verbose = interactive(),
  record_every = 10,
  windows = 1
)
```

## Arguments

- problem:

  A `pinn_problem`.

- hidden:

  Integer vector of hidden layer widths.

- activation:

  Activation function; see
  [`pinn_mlp()`](https://obasanmii.github.io/pinnr/reference/pinn_mlp.md).

- epochs:

  Number of Adam steps.

- lr:

  Adam learning rate for the network weights.

- lr_unknown:

  Adam learning rate for unknown parameters. Defaults to `10 * lr`.

- lbfgs_iter:

  Number of L-BFGS iterations after Adam (0 to skip).

- n_collocation:

  Number of points inside the domain where the residual is evaluated.

- sampling:

  `"lhs"` (Latin hypercube) or `"uniform"`.

- resample_every:

  Draw new collocation and condition points every this many Adam steps
  (0 keeps one fixed set). Resampling reduces overfitting to the
  training points.

- weights:

  Named numeric vector with loss weights `residual`, `conditions` and
  `data`. Missing names default to 1.

- precision:

  `"float32"` (default) or `"float64"`. Double precision is slower but
  can help L-BFGS reach smaller losses.

- device:

  A torch device, such as `"cpu"`, `"cuda"` or `"mps"`.

- seed:

  Optional integer seed for reproducible sampling and weights.

- verbose:

  Print progress messages.

- record_every:

  Store the loss every this many steps.

- windows:

  Number of time windows for ODE problems; see *Long time horizons*.

## Value

An object of class `pinn_fit`, with methods for
[`predict()`](https://rdrr.io/r/stats/predict.html),
[`coef()`](https://rdrr.io/r/stats/coef.html),
[`residuals()`](https://rdrr.io/r/stats/residuals.html),
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) and
[`summary()`](https://rdrr.io/r/base/summary.html).

## Choosing settings

The defaults solve small problems on a CPU in seconds to minutes. If the
loss stalls, try more epochs, a wider or deeper network, more
collocation points, or `lbfgs_iter = 500`. For parameter estimation, a
larger `lr_unknown` lets the parameters move faster than the network
weights. Long time horizons are hard for PINNs; shorter windows, or more
data, help.

## Long time horizons

PINNs often converge to a wrong, flat solution when an ODE is solved
over a long horizon with fast early dynamics (for example an epidemic
starting from a few cases). For problems from
[`pinn_ode()`](https://obasanmii.github.io/pinnr/reference/pinn_ode.md),
`windows = k` splits the time range into `k` equal windows and trains
one network per window, each starting from the end state of the previous
one ("time marching"). This is available for forward problems (no
`unknown` parameters).

Pressing Esc (or Ctrl+C) stops training early and returns the model as
trained so far, with a warning. If the loss becomes `NaN` or infinite,
training stops and the weights with the lowest loss seen so far are
returned, also with a warning (and `diverged = TRUE` in the result).

## Examples

``` r
# Exponential decay dy/dt = -k y
decay <- function(t, y, parms) list(-parms["k"] * y)
prob <- pinn_ode(decay, y0 = c(y = 1), times = seq(0, 5, by = 0.5),
                 parms = c(k = 0.5))
fit <- pinn_fit(prob, hidden = c(16, 16), epochs = 1500, seed = 1)
head(predict(fit))
#>   time         y
#> 1  0.0 1.0000000
#> 2  0.5 0.8026445
#> 3  1.0 0.6265597
#> 4  1.5 0.4774747
#> 5  2.0 0.3590537
#> 6  2.5 0.2713972
```
