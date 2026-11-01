# Fully connected network used by pinnr

A multilayer perceptron with Xavier-normal initial weights and zero
biases, the standard choice for PINNs.

## Usage

``` r
pinn_mlp(n_in, hidden = c(32, 32, 32), n_out = 1, activation = "tanh")
```

## Arguments

- n_in:

  Number of inputs.

- hidden:

  Integer vector of hidden layer widths.

- n_out:

  Number of outputs.

- activation:

  `"tanh"` (default), `"sin"`, `"silu"`, `"gelu"` or `"softplus"`.
  Smooth activations are needed because the loss involves derivatives of
  the network; avoid ReLU.

## Value

A
[`torch::nn_module`](https://torch.mlverse.org/docs/reference/nn_module.html).

## Examples

``` r
net <- pinn_mlp(2, c(16, 16), 1)
net(torch::torch_randn(5, 2))
#> torch_tensor
#> -0.6970
#> -0.2253
#> -0.0910
#>  0.6885
#> -0.5907
#> [ CPUFloatType{5,1} ][ grad_fn = <AddmmBackward0> ]
```
