# Define a physics-informed problem

Collects everything a PINN needs: the domain, the names of the unknown
functions, the equation residual, conditions, optional observations and
the equation's parameters.

## Usage

``` r
pinn_problem(
  domain,
  outputs,
  residual,
  conditions = list(),
  data = NULL,
  parms = list(),
  unknown = NULL,
  positive = TRUE,
  transform = NULL
)
```

## Arguments

- domain:

  A
  [`pinn_domain()`](https://obasanmii.github.io/pinnr/reference/pinn_domain.md),
  or a named list of ranges.

- outputs:

  Character vector naming the unknown functions.

- residual:

  Function returning the equation residual. See *Writing the residual*.

- conditions:

  A condition or list of conditions from
  [`pinn_dirichlet()`](https://obasanmii.github.io/pinnr/reference/conditions.md),
  [`pinn_neumann()`](https://obasanmii.github.io/pinnr/reference/conditions.md),
  [`pinn_initial()`](https://obasanmii.github.io/pinnr/reference/conditions.md)
  or
  [`pinn_condition()`](https://obasanmii.github.io/pinnr/reference/conditions.md).

- data:

  Optional data frame of observations, with one column per domain
  variable and one column for each observed output. Missing values
  (`NA`) are ignored, so outputs can be observed at different points.

- parms:

  Named list or numeric vector of known constants.

- unknown:

  Named numeric vector of initial guesses for parameters to estimate.

- positive:

  Logical, recycled or named by `unknown`. Positive parameters are
  estimated on the log scale, which keeps them positive and usually
  helps convergence.

- transform:

  Optional output transform. See *Output transforms*.

## Value

An object of class `pinn_problem`.

## Writing the residual

`residual` is an R function whose arguments are matched **by name** to:

- the outputs (for example `u`),

- the domain variables (for example `x`, `t`),

- the parameters in `parms` and `unknown`, and

- `d`, the derivative operator.

`d(f, x)` differentiates `f` with respect to the variable `x`;
`d(f, x, x)` gives the second derivative and `d(f, x, t)` a mixed
derivative. The function returns the expression that should equal zero,
or a list of such expressions for a system of equations. For the viscous
Burgers equation \\u_t + u u_x - \nu u\_{xx} = 0\\:

    function(u, x, t, nu, d) d(u, t) + u * d(u, x) - nu * d(u, x, x)

All arguments are torch tensors with one row per point, so use
arithmetic and maths functions (`sin`, `exp`, `log`, `sqrt`, ...) and
avoid `if`, `ifelse` or functions that leave R's torch methods.

## Output transforms

`transform` can enforce conditions exactly ("hard constraints"). It is
called with the raw network outputs, domain variables and parameters
(matched by name, as above) and returns a named list of modified
outputs. For example, to make \\u(0, t) = u(1, t) = 0\\ hold exactly:
`transform = function(u, x) list(u = x * (1 - x) * u)`.

## See also

[`pinn_ode()`](https://obasanmii.github.io/pinnr/reference/pinn_ode.md)
for ordinary differential equations written in `deSolve` style, and
[`pinn_fit()`](https://obasanmii.github.io/pinnr/reference/pinn_fit.md)
to train the network.

## Examples

``` r
# Heat equation u_t = a u_xx with u(x, 0) = sin(pi x) and u = 0 at both ends
heat <- pinn_problem(
  domain = pinn_domain(x = c(0, 1), t = c(0, 1)),
  outputs = "u",
  residual = function(u, x, t, a, d) d(u, t) - a * d(u, x, x),
  conditions = list(
    pinn_initial(function(x) sin(pi * x), time = "t"),
    pinn_dirichlet(where = list(x = "both"), value = 0)
  ),
  parms = list(a = 0.1)
)
heat
#> <pinn_problem>
#>   Domain:     x in [0, 1], t in [0, 1]
#>   Outputs:    u
#>   Parameters: a = 0.1
#>   Conditions:
#>     <pinn_condition: initial at t = lower, n = 100>
#>     <pinn_condition: dirichlet at x = both, n = 100>
```
