#' Fully connected network used by pinnr
#'
#' A multilayer perceptron with Xavier-normal initial weights and zero
#' biases, the standard choice for PINNs.
#'
#' @param n_in Number of inputs.
#' @param hidden Integer vector of hidden layer widths.
#' @param n_out Number of outputs.
#' @param activation `"tanh"` (default), `"sin"`, `"silu"`, `"gelu"` or
#'   `"softplus"`. Smooth activations are needed because the loss involves
#'   derivatives of the network; avoid ReLU.
#' @return A `torch::nn_module`.
#' @examplesIf torch::torch_is_installed()
#' net <- pinn_mlp(2, c(16, 16), 1)
#' net(torch::torch_randn(5, 2))
#' @export
pinn_mlp <- function(n_in, hidden = c(32, 32, 32), n_out = 1,
                     activation = "tanh") {
  pinn_mlp_module(n_in, hidden, n_out, activation)
}

pinn_mlp_module <- nn_module(
  "pinn_mlp",
  initialize = function(n_in, hidden = c(32, 32, 32), n_out = 1,
                        activation = "tanh") {
    layers <- list()
    width <- n_in
    for (h in hidden) {
      lin <- nn_linear(width, h)
      nn_init_xavier_normal_(lin$weight)
      nn_init_zeros_(lin$bias)
      layers <- c(layers, list(lin, make_activation(activation)))
      width <- h
    }
    last <- nn_linear(width, n_out)
    nn_init_xavier_normal_(last$weight)
    nn_init_zeros_(last$bias)
    layers <- c(layers, list(last))
    self$net <- do.call(nn_sequential, layers)
  },
  forward = function(x) {
    self$net(x)
  }
)

nn_sine <- nn_module(
  "nn_sine",
  forward = function(x) torch_sin(x)
)

activation_names <- c("tanh", "sin", "silu", "gelu", "softplus")

make_activation <- function(activation) {
  switch(
    activation,
    tanh = nn_tanh(),
    sin = nn_sine(),
    silu = nn_silu(),
    gelu = nn_gelu(),
    softplus = nn_softplus(),
    stop(sprintf("Unknown activation \"%s\". Use one of: %s.", activation,
                 paste(activation_names, collapse = ", ")), call. = FALSE)
  )
}
