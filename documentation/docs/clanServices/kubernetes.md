# clanServices/kubernetes

Kubernetes is a service that allows you to create a kubernetes cluster. 

## Requirements
- [cluster-mesh service](https://home.andrewlee.cloud/clanServices/cluster-mesh.html){:target="_blank"}

## Usage
`flake.nix` should contain the following:
```nix
inputs.andrewthomaslee.url = "github:andrewthomaslee/home";
```

`inventory.nix` should contain the following:
```nix
# Kubernetes Cluster for Home
instances = {
    home = {
        module.name = "@andrewthomaslee/kubernetes";
        module.input = "andrewthomaslee";
        roles.init.machines.kamrui-p1.settings = {
            clusterCidr = "10.42.0.0/16,fd42::/56";
            serviceCidr = "10.43.0.0/16,fd43::/112";
        };
        roles.server.tags = ["home-server"]; # Manager Nodes
        roles.default.tags = ["home-agent"]; # Apply to All Nodes reguardless of role
    };
};
```