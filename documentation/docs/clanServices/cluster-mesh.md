# clanServices/cluster-mesh

Cluster Mesh is a service that allows you to connect multiple NixOS machines together using WireGuard. Inspried by [wireguard-star](https://git.clan.lol/clan/clan-community/src/branch/main/services/wireguard-star/README.md){:target="_blank"}

## Usage
`flake.nix` should contain the following:
```nix
inputs.andrewthomaslee.url = "github:andrewthomaslee/home";
```

`inventory.nix` should contain the following:
```nix
# Cluster Mesh
instances = {
    cluster-mesh = {
        module.name = "@andrewthomaslee/cluster-mesh";
        module.input = "andrewthomaslee";
        roles.peer.machines = {
            server1.settings = {
                endpoint = "server1.domain.com";
                port = 51823;
                ipv4 = "10.67.67.1";
                ipv6 = "fd67:67::1";
            };
            server2.settings = {
                endpoint = "server2.domain.com";
                port = 51820;
                ipv4 = "10.67.67.2";
                ipv6 = "fd67:67::2";
            };
        };
    };    
};

```