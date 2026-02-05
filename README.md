# nixos-homeprod

Managing a "Homeprod" configuration using NixOS.

## Why?

For the longest time I ran a Kubernetes cluster at home for almost all of my 'production' applications and realised how much actual overhead was being introduced with the supporting tooling to manage the cluster. For example I also ran:

* Longhorn for persistent storage
* Prometheus stack for monitoring
* MetalLB, Traefik, external DNS, cert-manager for Ingress
* Kured, system-upgrade 

This is just to get the cluster in a daily managable state.

So it is time to simplify, and with that I like the defined state of Kubernetes, so why not keep to that with using NixOS to manage containers and services?
