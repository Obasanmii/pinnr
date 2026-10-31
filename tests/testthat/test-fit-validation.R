# These checks run before any torch code, so they work without libtorch.
decay <- function(t, y, parms) list(-parms["k"] * y)
prob <- pinn_ode(decay, c(y = 1), c(0, 2), parms = c(k = 1))

test_that("pinn_fit validates its arguments", {
  expect_error(pinn_fit(list()), "pinn_problem")
  expect_error(pinn_fit(prob, hidden = 0), "hidden")
  expect_error(pinn_fit(prob, hidden = 2.5), "hidden")
  expect_error(pinn_fit(prob, hidden = c(8, NA)), "hidden")
  expect_error(pinn_fit(prob, epochs = Inf), "epochs")
  expect_error(pinn_fit(prob, lr = Inf), "lr")
  expect_error(pinn_fit(prob, activation = "relu"), "activation")
  expect_error(pinn_fit(prob, epochs = -1), "epochs")
  expect_error(pinn_fit(prob, epochs = 0, lbfgs_iter = 0), "above zero")
  expect_error(pinn_fit(prob, lr = 0), "lr")
  expect_error(pinn_fit(prob, weights = c(foo = 1)), "weights")
  expect_error(pinn_fit(prob, weights = c(data = -1)), "weights")
  expect_error(pinn_fit(prob, sampling = "grid"), "should be one of")
  expect_error(pinn_fit(prob, windows = 0), "windows")
})

test_that("time windows require a forward ODE problem", {
  heat <- pinn_problem(pinn_domain(x = c(0, 1)), "u",
                       function(u, x, d) d(u, x, x),
                       conditions = pinn_dirichlet(list(x = "both"), 0))
  expect_error(pinn_fit(heat, windows = 2), "pinn_ode")
  inv <- pinn_ode(decay, c(y = 1), c(0, 2), unknown = c(k = 2),
                  data = data.frame(time = 1, y = exp(-1)))
  expect_error(pinn_fit(inv, windows = 2), "unknown parameters")
})

test_that("weights are completed with defaults", {
  expect_equal(pinnr:::check_weights(c(data = 5)),
               c(residual = 1, conditions = 1, data = 5))
})

test_that("a helpful error appears when the torch backend is missing", {
  skip_if(requireNamespace("torch", quietly = TRUE) && torch::torch_is_installed(),
          "torch backend is installed")
  expect_error(pinn_fit(prob), "install_torch")
})
