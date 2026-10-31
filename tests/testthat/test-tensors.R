test_that("tensors built from R data own their memory", {
  skip_if_no_torch()
  # torch_tensor() aliases an n x 1 double matrix when dtype is float64, so two
  # tensors from the same matrix share one buffer: the R object's memory.
  x <- matrix(c(1, 2, 3), ncol = 1)
  for (dt in list(torch::torch_float64(), torch::torch_float32())) {
    a <- pinnr:::r_tensor(x, dtype = dt)
    b <- pinnr:::r_tensor(x, dtype = dt)
    expect_false(identical(a$storage()$data_ptr(), b$storage()$data_ptr()))
    expect_equal(as.numeric(torch::as_array(a)), c(1, 2, 3))
  }
  g <- pinnr:::r_tensor(x, dtype = torch::torch_float64(), requires_grad = TRUE)
  expect_true(g$requires_grad)
  expect_true(g$is_leaf)
})

test_that("float64 training with L-BFGS and resampling stays finite", {
  skip_if_no_torch()
  decay <- function(t, y, parms) list(-parms["k"] * y)
  prob <- pinn_ode(decay, y0 = c(y = 1), times = c(0, 2), parms = c(k = 1))
  for (s in 1:3) {
    fit <- suppressWarnings(
      pinn_fit(prob, hidden = c(8, 8), epochs = 100, lbfgs_iter = 20,
               precision = "float64", resample_every = 10,
               sampling = "uniform", activation = "sin", seed = s,
               verbose = FALSE)
    )
    expect_true(is.finite(fit$final_loss[["total"]]))
  }
})
