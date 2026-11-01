# Package index

## Define a problem

- [`pinn_ode()`](https://obasanmii.github.io/pinnr/reference/pinn_ode.md)
  : Build a problem from a deSolve-style ODE model
- [`pinn_problem()`](https://obasanmii.github.io/pinnr/reference/pinn_problem.md)
  : Define a physics-informed problem
- [`pinn_domain()`](https://obasanmii.github.io/pinnr/reference/pinn_domain.md)
  : Define a rectangular domain
- [`pinn_dirichlet()`](https://obasanmii.github.io/pinnr/reference/conditions.md)
  [`pinn_neumann()`](https://obasanmii.github.io/pinnr/reference/conditions.md)
  [`pinn_initial()`](https://obasanmii.github.io/pinnr/reference/conditions.md)
  [`pinn_condition()`](https://obasanmii.github.io/pinnr/reference/conditions.md)
  : Boundary, initial and custom conditions

## Train

- [`pinn_fit()`](https://obasanmii.github.io/pinnr/reference/pinn_fit.md)
  : Train a physics-informed neural network
- [`pinn_mlp()`](https://obasanmii.github.io/pinnr/reference/pinn_mlp.md)
  : Fully connected network used by pinnr
- [`pinn_sample()`](https://obasanmii.github.io/pinnr/reference/pinn_sample.md)
  : Sample points in a domain

## Inspect and save a fit

- [`predict(`*`<pinn_fit>`*`)`](https://obasanmii.github.io/pinnr/reference/predict.pinn_fit.md)
  : Predict from a fitted PINN
- [`residuals(`*`<pinn_fit>`*`)`](https://obasanmii.github.io/pinnr/reference/residuals.pinn_fit.md)
  : Equation residuals of a fitted PINN
- [`coef(`*`<pinn_fit>`*`)`](https://obasanmii.github.io/pinnr/reference/coef.pinn_fit.md)
  : Estimated parameters
- [`plot(`*`<pinn_fit>`*`)`](https://obasanmii.github.io/pinnr/reference/plot.pinn_fit.md)
  : Plot a fitted PINN
- [`pinn_save()`](https://obasanmii.github.io/pinnr/reference/pinn_save.md)
  [`pinn_load()`](https://obasanmii.github.io/pinnr/reference/pinn_save.md)
  : Save and load fitted PINNs

## Package

- [`pinnr`](https://obasanmii.github.io/pinnr/reference/pinnr-package.md)
  [`pinnr-package`](https://obasanmii.github.io/pinnr/reference/pinnr-package.md)
  : pinnr: Physics-Informed Neural Networks in Native R
