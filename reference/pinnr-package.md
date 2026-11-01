# pinnr: Physics-Informed Neural Networks in Native R

`pinnr` trains neural networks whose outputs satisfy a differential
equation. A network \\u\_\theta(x)\\ is fitted by minimising a weighted
sum of

- the mean squared equation residual at collocation points inside the
  domain,

- the mean squared violation of boundary and initial conditions, and

- the mean squared misfit to observed data, when data are supplied.

## Details

Unknown constants in the equation can be estimated jointly with the
network weights, which turns the same machinery into a tool for
parameter discovery (an inverse problem).

The main entry points are:

- [`pinn_ode()`](https://obasanmii.github.io/pinnr/reference/pinn_ode.md)
  builds a problem from a `deSolve`-style derivative function.

- [`pinn_problem()`](https://obasanmii.github.io/pinnr/reference/pinn_problem.md)
  builds a problem for any partial differential equation on a
  rectangular domain defined with
  [`pinn_domain()`](https://obasanmii.github.io/pinnr/reference/pinn_domain.md),
  with conditions from
  [`pinn_dirichlet()`](https://obasanmii.github.io/pinnr/reference/conditions.md),
  [`pinn_neumann()`](https://obasanmii.github.io/pinnr/reference/conditions.md),
  [`pinn_initial()`](https://obasanmii.github.io/pinnr/reference/conditions.md)
  and
  [`pinn_condition()`](https://obasanmii.github.io/pinnr/reference/conditions.md).

- [`pinn_fit()`](https://obasanmii.github.io/pinnr/reference/pinn_fit.md)
  trains the network.

- [predict()](https://obasanmii.github.io/pinnr/reference/predict.pinn_fit.md),
  [coef()](https://obasanmii.github.io/pinnr/reference/coef.pinn_fit.md),
  [residuals()](https://obasanmii.github.io/pinnr/reference/residuals.pinn_fit.md)
  and
  [plot()](https://obasanmii.github.io/pinnr/reference/plot.pinn_fit.md)
  inspect the result.

## References

Raissi, M., Perdikaris, P. and Karniadakis, G. E. (2019).
Physics-informed neural networks: A deep learning framework for solving
forward and inverse problems involving nonlinear partial differential
equations. *Journal of Computational Physics*, 378, 686-707.
[doi:10.1016/j.jcp.2018.10.045](https://doi.org/10.1016/j.jcp.2018.10.045)

## See also

Useful links:

- <https://github.com/Obasanmii/pinnr>

- Report bugs at <https://github.com/Obasanmii/pinnr/issues>

## Author

**Maintainer**: Samson Obasanmi <obasanmisamson722@gmail.com>
([ORCID](https://orcid.org/0009-0009-6935-5479))

Authors:

- Samson Obasanmi <obasanmisamson722@gmail.com>
  ([ORCID](https://orcid.org/0009-0009-6935-5479))
