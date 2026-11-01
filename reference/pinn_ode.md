# Build a problem from a deSolve-style ODE model

Turns an ordinary differential equation written for
[`deSolve::ode()`](https://rdrr.io/pkg/deSolve/man/ode.html) into a
[`pinn_problem()`](https://obasanmii.github.io/pinnr/reference/pinn_problem.md).
The same derivative function can be used to solve the system (a forward
problem) or, with `unknown` and `data`, to estimate its parameters from
observations.

## Usage

``` r
pinn_ode(
  func,
  y0,
  times,
  parms = NULL,
  unknown = NULL,
  positive = TRUE,
  data = NULL,
  time = "time",
  hard_initial = TRUE
)
```

## Arguments

- func:

  A derivative function `function(t, y, parms)` in `deSolve` style. See
  *Writing the model*.

- y0:

  Named numeric vector of initial states at the first time.

- times:

  Numeric vector of times. Only its range is used for training; the full
  vector becomes the default grid for
  [`predict()`](https://rdrr.io/r/stats/predict.html).

- parms:

  Named numeric vector or list of known parameters.

- unknown:

  Named numeric vector of initial guesses for parameters to estimate.
  These are passed to `func` alongside `parms`.

- positive:

  Logical; see
  [`pinn_problem()`](https://obasanmii.github.io/pinnr/reference/pinn_problem.md).

- data:

  Optional data frame of observations with a column named as `time` and
  one column per observed state. The output of
  [`deSolve::ode()`](https://rdrr.io/pkg/deSolve/man/ode.html) converted
  with [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
  works directly.

- time:

  Name of the time variable. The default, `"time"`, matches the column
  name in `deSolve` output.

- hard_initial:

  Logical; enforce the initial state exactly. See *Initial conditions*.

## Value

A
[`pinn_problem()`](https://obasanmii.github.io/pinnr/reference/pinn_problem.md)
object.

## Writing the model

`func` has the usual `deSolve` signature `function(t, y, parms)` and
returns a list whose first element holds the derivatives, in the order
of `y0`. The recommended style works unchanged:

    function(t, y, parms) {
      with(as.list(c(y, parms)), {
        dS <- -beta * S * I
        ...
        list(c(dS, dI, dR))
      })
    }

Indexing with `y["S"]`, `y[1]` or `parms["beta"]` also works. Because
the states are torch tensors, the body must use arithmetic and maths
functions; `if`, `ifelse`, `max` and `pmin` on states do not work.
Forcing functions of time can be written with tensor operations, for
example `torch_sin(t)` or `sin(t)`.

## Initial conditions

By default the initial state is enforced exactly by writing each state
as \\y(t) = y_0 + \frac{t - t_0}{t_1 - t_0} N(t)\\, where \\N\\ is the
network. This removes one loss term and usually speeds up training. Set
`hard_initial = FALSE` to use a soft penalty instead.

## Examples

``` r
# Logistic growth dN/dt = r N (1 - N / K)
logistic <- function(t, y, parms) {
  with(as.list(c(y, parms)), list(r * N * (1 - N / K)))
}
prob <- pinn_ode(logistic, y0 = c(N = 0.1), times = seq(0, 10, by = 0.5),
                 parms = c(r = 1, K = 1))
prob
#> <pinn_problem>
#>   Domain:     time in [0, 10]
#>   Outputs:    N
#>   Parameters: r = 1, K = 1
#>   Output transform: yes
```
