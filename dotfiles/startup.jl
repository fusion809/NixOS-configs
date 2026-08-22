#!/usr/bin/env julia
using Distributions
function pnorm(x)
    cdf(Normal(), x)
end

function p2norm(x)
    pnorm(x)-pnorm(-x)
end

function qnorm(x)
    quantile(Normal(), x)
end

function q2norm(x)
    quantile(Normal(), 1-(1-x)/2)
end

function qnormg(x, mu, sigma)
    quantile(Normal(mu, sigma), x)
end

function q2normg(x, mu, sigma)
    quantile(Normal(mu, sigma), 1-(1-x)/2)
end
