# Clan Exports Guide

Clan exports provide a powerful system for sharing structured data between machines, instances, and roles within your Clan infrastructure. This is essential for building distributed systems like Kubernetes clusters or VPN meshes where nodes need to discover each other dynamically.

## 1. The Concept of Exports

When a machine evaluates a clanService, it can "export" data. This data is collected globally by the Clan flake into an attribute set (`clan.exports`). Other machines can then query this global set to configure themselves.

Exports are strictly typed using **Export Interfaces**. By default, Clan provides interfaces like `endpoints`, `peer`, `networking`, `auth`, `dataMesher`, and `generators`. 

## 2. Creating a Custom Export Interface

If the built-in interfaces don't fit your needs (e.g., you need to share Kubernetes cluster IDs, IP addresses, and ports), you can create a custom export interface.

Custom interfaces are defined in your flake's `clan` configuration (often located in `flake-parts/default.nix`).

```nix
# flake-parts/default.nix
{
  flake = {
    clan = {
      # Define custom export interfaces here
      exportInterfaces.kubernetesMesh = { lib, ... }: {
        options.clusterId = lib.mkOption {
          type = lib.types.int;
          description = "The unique ID of the Kubernetes cluster";
        };
        options.address = lib.mkOption {
          type = lib.types.str;
          description = "The IP address of the cluster";
        };
      };
      
      modules = {
        "@andrewthomaslee/kubernetes" = ../clanServices/kubernetes;
      };
    };
  };
}
```

## 3. Exporting Data from a Service

In your service definition (e.g., `clanServices/kubernetes/default.nix`), you must declare which interfaces your service exports using `manifest.exports.out`.

Then, use `mkExports` within `perInstance` (or `perMachine`) to publish the data.

```nix
# clanServices/kubernetes/default.nix
{ clanLib, lib, ... }: {
  _class = "clan.service";
  manifest.name = "kubernetes";
  
  # Declare the custom interface
  manifest.exports.out = [ "kubernetesMesh" ];

  roles.server = {
    perInstance = { settings, mkExports, ... }: {
      # Export the structured data
      exports = mkExports {
        kubernetesMesh.clusterId = settings.id;
        kubernetesMesh.address = settings.address;
      };

      nixosModule = { ... }: {
        # Local machine configuration...
      };
    };
  };
}
```

## 4. Sharing Data Between Instances of the Same Service

To read exported data, you use `clanLib.selectExports`. 

**Crucial Detail:** `selectExports` requires a **predicate function** that filters scopes, *not* an attribute set as older documentation might suggest.

To share data across multiple instances of the *same* clanService (e.g., `cluster-1` and `cluster-2`), filter the scope by `serviceName`.

```nix
  roles.server = {
    perInstance = { exports, clanLib, ... }: {
      nixosModule = { ... }: {
        
        # 1. Retrieve all exports for the "kubernetes" service across ALL instances
        environment.etc."k8s-mesh.json".text = builtins.toJSON (
          clanLib.selectExports (scope: scope.serviceName == "kubernetes") exports
        );
        
      };
    };
  };
```

When you evaluate this, the returned data structure will map the fully qualified scope keys to the exported data, allowing `cluster-1` to see `cluster-2`'s configuration:

```json
{
  "kubernetes:cluster-1:server:node-1": {
    "kubernetesMesh": {
      "address": "10.67.67.1",
      "clusterId": 1
    }
  },
  "kubernetes:cluster-2:server:node-2": {
    "kubernetesMesh": {
      "address": "10.67.67.2",
      "clusterId": 2
    }
  }
}
```

By leveraging custom export interfaces and cross-instance querying, you can build highly scalable, dynamically meshed services in Clan.
