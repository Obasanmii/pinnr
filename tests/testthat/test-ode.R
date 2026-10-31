sir <- function(t, y, parms) {
  with(as.list(c(y, parms)), {
    dS <- -beta * S * I
    dI <- beta * S * I - gamma * I
    dR <- gamma * I
    list(c(dS, dI, dR))
  })
}

test_that("pinn_ode builds a problem with metadata", {
  p <- pinn_ode(sir, y0 = c(S = 0.99, I = 0.01, R = 0), times = 0:50,
                parms = c(beta = 0.3, gamma = 0.1))
  expect_s3_class(p, "pinn_problem")
  expect_equal(p$domain$vars, "time")
  expect_equal(unname(c(p$domain$lower, p$domain$upper)), c(0, 50))
  expect_equal(p$outputs, c("S", "I", "R"))
  expect_equal(p$meta$type, "ode")
  expect_length(p$conditions, 0)
  expect_true(is.function(p$transform))

  soft <- pinn_ode(sir, c(S = 0.99, I = 0.01, R = 0), c(0, 50),
                   parms = c(beta = 0.3, gamma = 0.1), hard_initial = FALSE)
  expect_null(soft$transform)
  expect_length(soft$conditions, 1)
})

test_that("the deSolve adaptor computes dy/dt - f", {
  p <- pinn_ode(sir, c(S = 0.99, I = 0.01, R = 0), c(0, 50),
                parms = c(beta = 0.3, gamma = 0.1))
  zero_d <- function(f, x) 0
  r <- p$residual(time = 1, S = 0.5, I = 0.2, R = 0.3, beta = 0.3,
                  gamma = 0.1, d = zero_d)
  expected <- -c(-0.3 * 0.5 * 0.2, 0.3 * 0.5 * 0.2 - 0.1 * 0.2, 0.1 * 0.2)
  expect_equal(unlist(r), expected)
})

test_that("indexing styles of deSolve models are supported", {
  by_index <- function(t, y, p) {
    list(c(-p["k"] * y[1], p["k"] * y["A"] - p[2] * y[[2]]))
  }
  p <- pinn_ode(by_index, c(A = 1, B = 0), c(0, 1), parms = c(k = 2, m = 3))
  r <- p$residual(time = 0, A = 1, B = 0.5, k = 2, m = 3,
                  d = function(f, x) 0)
  expect_equal(unlist(r), c(2, -(2 - 1.5)))

  one_state <- function(t, y, p) list(p["r"] * y * (1 - y / p["K"]))
  p1 <- pinn_ode(one_state, c(N = 0.5), c(0, 1), parms = c(r = 1, K = 2))
  r1 <- p1$residual(time = 0, N = 0.5, r = 1, K = 2, d = function(f, x) 0)
  expect_equal(r1[[1]], -(0.5 * 0.75))
})

test_that("the hard initial condition transform starts at y0", {
  p <- pinn_ode(sir, c(S = 0.99, I = 0.01, R = 0), c(10, 30),
                parms = c(beta = 0.3, gamma = 0.1))
  tr <- p$transform(time = c(10, 20, 30), S = 1, I = 1, R = 1)
  expect_equal(tr$S, c(0.99, 1.49, 1.99))
  expect_equal(tr$R, c(0, 0.5, 1))
})

test_that("pinn_state behaves like a deSolve state vector", {
  y <- pinnr:::new_state(list(S = 2, I = 3))
  expect_equal(y["S"], 2)
  expect_equal(y[2], 3)
  expect_equal(with(as.list(c(y, list(k = 4))), S * I * k), 24)
  expect_error(y * 2, "one-state")
  one <- pinnr:::new_state(list(N = 4))
  expect_equal(one * 2, 8)
  expect_equal(2 - one, -2)
  expect_equal(-one, -4)
  expect_equal(sqrt(one), 2)
})

test_that("derivative extraction checks the returned shape", {
  f <- pinnr:::ode_derivatives
  expect_equal(f(list(c(1, 2)), c("a", "b")), list(1, 2))
  expect_equal(f(list(list(1, 2)), c("a", "b")), list(1, 2))
  expect_equal(f(list(0), c("a", "b")), list(0, 0))
  expect_error(f(list(list(1, 2, 3)), c("a", "b")), "one derivative per state")
  expect_error(f("x", "a"), "one derivative per state")
})

test_that("pinn_ode validates input", {
  expect_error(pinn_ode(1, c(y = 1), c(0, 1)), "function")
  expect_error(pinn_ode(sir, c(1, 2), c(0, 1)), "named")
  expect_error(pinn_ode(sir, c(y = 1), 1), "at least two")
  expect_error(pinn_ode(sir, c(y = 1), c(1, 1)), "non-zero")
})

test_that("observations from deSolve output are accepted", {
  dat <- data.frame(time = c(0, 10, 20), S = c(0.99, 0.9, 0.6),
                    I = c(0.01, 0.07, 0.25), R = c(0, 0.03, 0.15))
  p <- pinn_ode(sir, c(S = 0.99, I = 0.01, R = 0), c(0, 20),
                unknown = c(beta = 0.5, gamma = 0.2), data = dat)
  expect_equal(nrow(p$data), 3)
  expect_equal(names(p$unknown$init), c("beta", "gamma"))
})
