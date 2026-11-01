# Boundary, initial and custom conditions

Conditions are enforced as soft penalties on points sampled where they
apply. Each condition fixes one or more domain variables (`where`) and
samples the remaining variables over their full range.

## Usage

``` r
pinn_dirichlet(
  where,
  value = 0,
  output = NULL,
  n = 100,
  weight = 1,
  name = NULL
)

pinn_neumann(
  where,
  along,
  value = 0,
  output = NULL,
  n = 100,
  weight = 1,
  name = NULL
)

pinn_initial(
  value,
  time = "t",
  output = NULL,
  n = 100,
  weight = 1,
  name = NULL
)

pinn_condition(where, fn, n = 100, weight = 1, name = NULL)
```

## Arguments

- where:

  Named list giving the fixed value(s) of one or more domain variables.
  See *Locations*.

- value:

  Target value. See *Values*.

- output:

  Name(s) of the output(s) the condition applies to. The default `NULL`
  applies it to every output.

- n:

  Number of points used for this condition.

- weight:

  Relative weight of this condition in the loss.

- name:

  Optional label used in printed output.

- along:

  Name of the domain variable to differentiate with respect to.

- time:

  Name of the time variable for `pinn_initial()`.

- fn:

  For `pinn_condition()`, a function returning the residual (a tensor,
  or a list of tensors) that should be zero. Arguments are matched by
  name to outputs, domain variables, parameters and the derivative
  operator `d` (see
  [`pinn_problem()`](https://obasanmii.github.io/pinnr/reference/pinn_problem.md)).

## Value

An object of class `pinn_condition`.

## Details

- `pinn_dirichlet()` fixes the value of the solution, \\u = g\\.

- `pinn_neumann()` fixes a first derivative, \\\partial u / \partial v =
  g\\.

- `pinn_initial()` is a Dirichlet condition at the lower end of the time
  variable.

- `pinn_condition()` takes any residual function, for Robin, periodic or
  other conditions.

## Locations

Each element of `where` is a number or one of the strings `"lower"`,
`"upper"` or `"both"`, which refer to the ends of that variable's range.
`where = list(x = "both")` places points on both ends of `x`. When
several variables are fixed, every combination of their values is used:
`where = list(x = "both", y = "both")` places points on the four
corners.

## Values

`value` can be a number, a numeric vector named by output, or a
function. A function's arguments are matched by name to the domain
variables, outputs and parameters, so `value = function(x) sin(pi * x)`
uses the spatial variable `x`. Inside these functions the arguments are
torch tensors, so use arithmetic and maths functions (`sin`, `exp`,
`log`, ...) rather than control flow such as `if` or `ifelse`.

## Examples

``` r
# u = 0 on both ends of x
pinn_dirichlet(where = list(x = "both"), value = 0)
#> <pinn_condition: dirichlet at x = both, n = 100>

# u(x, 0) = sin(pi x)
pinn_initial(function(x) sin(pi * x), time = "t")
#> <pinn_condition: initial at t = lower, n = 100>

# insulated right boundary: du/dx = 0 at x = 1
pinn_neumann(where = list(x = "upper"), along = "x")
#> <pinn_condition: neumann at x = upper, n = 100>

# Robin condition du/dx + 2 u = 0 at x = 1, as a custom residual
pinn_condition(where = list(x = "upper"),
               fn = function(u, x, d) d(u, x) + 2 * u)
#> <pinn_condition: custom at x = upper, n = 100>
```
