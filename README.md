# pinnr

<!-- badges: start -->
[![R-CMD-check](https://github.com/Obasanmii/pinnr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Obasanmii/pinnr/actions/workflows/R-CMD-check.yaml)
[![R-universe](https://obasanmii.r-universe.dev/badges/pinnr)](https://obasanmii.r-universe.dev/pinnr)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23835717.svg)](https://doi.org/10.5281/zenodo.23835717)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**Physics-informed neural networks in native R.**

`pinnr` trains neural networks that satisfy differential equations. Use it
to solve ordinary and partial differential equations, or to estimate the
unknown parameters of a model from observations. It runs on R's
[`torch`](https://torch.mlverse.org), with no Python dependency, and it
accepts ODE models written for [`deSolve`](https://cran.r-project.org/package=deSolve)
without changes.

## Why pinnr?

R has excellent classical solvers for differential equations, but
physics-informed neural networks have so far required Python libraries
such as DeepXDE, or R packages built for a single application. `pinnr`
provides a general, R-native interface:

* **Use your deSolve models directly.** `pinn_ode()` takes the same
  `function(t, y, parms)` you already wrote.
* **Estimate parameters from data.** List unknown constants and supply
  observations; they are learned with the network. States can be partly
  observed, at different times, with missing values.
* **Write PDEs as R functions.** Residuals are plain functions with
  arguments matched by name, and `d(u, x, x)` for derivatives.
* **Conditions for real problems.** Dirichlet, Neumann, initial and custom
  (Robin, periodic, ...) conditions, plus exact "hard" constraints through
  output transforms.
* **Practical training.** Adam followed by optional L-BFGS, Latin
  hypercube sampling with resampling, time marching for long ODE horizons,
  GPU support, reproducible seeds, and stopping early with Esc without losing the model.

## Installation

Install the pre-built package from R-universe:

```r
install.packages("pinnr", repos = c("https://obasanmii.r-universe.dev",
                                    "https://cloud.r-project.org"))
torch::install_torch()   # once, if you have not used torch before
```

or the development version from GitHub:

```r
# install.packages("remotes")
remotes::install_github("Obasanmii/pinnr")
```

On Intel Macs running macOS 14 or older, torch 0.17.0 cannot load its
backend (its Intel build of LibTorch requires macOS 15). Install torch 0.16.3
instead, then run `torch::install_torch()`.

## Example: estimating epidemic parameters

```r
library(pinnr)

sir <- function(t, y, parms) {
  with(as.list(c(y, parms)), {
    dS <- -beta * S * I
    dI <- beta * S * I - gamma * I
    dR <- gamma * I
    list(c(dS, dI, dR))
  })
}
y0 <- c(S = 0.99, I = 0.01, R = 0)

# simulate observations of I and R with deSolve
ref <- as.data.frame(deSolve::ode(y0, 0:100, sir, c(beta = 0.3, gamma = 0.1)))
obs <- ref[ref$time %% 5 == 0, c("time", "I", "R")]

prob <- pinn_ode(sir, y0 = y0, times = 0:100,
                 unknown = c(beta = 0.5, gamma = 0.2), data = obs)
fit <- pinn_fit(prob, epochs = 5000, seed = 1)
coef(fit)
#>  beta gamma
#> ~0.30 ~0.10
```

## Example: the heat equation

```r
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
fit <- pinn_fit(heat, epochs = 5000)
plot(fit, type = "solution")
```

See `vignette("pinnr")` or the [website](https://obasanmii.github.io/pinnr/) for a full walkthrough.

## Main functions

| Function | Purpose |
|---|---|
| `pinn_ode()` | Problem from a `deSolve`-style ODE model |
| `pinn_problem()`, `pinn_domain()` | General PDE problem on a rectangular domain |
| `pinn_dirichlet()`, `pinn_neumann()`, `pinn_initial()`, `pinn_condition()` | Conditions |
| `pinn_fit()` | Train the network |
| `predict()`, `residuals()`, `coef()`, `plot()`, `summary()` | Inspect a fit |
| `pinn_save()`, `pinn_load()` | Store fits on disk |

## Limitations

`pinnr` is young. Domains are rectangles (time intervals, lines, boxes),
residuals must use tensor-friendly operations, and, as with all PINNs,
training is slower than a classical solver for problems those solvers
handle well. PINNs are most useful for inverse problems, sparse or noisy
data, and settings where a smooth, differentiable surrogate is helpful.

## Contributing

Bug reports and pull requests are welcome; see
[CONTRIBUTING.md](CONTRIBUTING.md). Please open an issue to discuss
larger changes first.

## Citation

If you use `pinnr` in your work, please cite it; see `citation("pinnr")`
or [CITATION.cff](CITATION.cff). The method is from Raissi, Perdikaris and
Karniadakis (2019), *Journal of Computational Physics* 378, 686-707,
<https://doi.org/10.1016/j.jcp.2018.10.045>.
