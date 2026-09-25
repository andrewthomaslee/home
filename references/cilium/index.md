# cilium

[Cilium](https://docs.cilium.io) is the eBPF-based networking, observability,
and security layer for Kubernetes. Load this reference when working on
Cilium networking: BGP peering (the v2 CRD-based control plane),
LoadBalancer IPAM, L2 announcements, or Cilium network policy.

This reference is written against **stable Cilium 1.20.x** — check the
stable version banner on docs.cilium.io if the cluster runs something
else. BGP resources below are `cilium.io/v2` (the "v2 BGP control
plane"); anything referencing kube-router or BIRD under the BGP section
of the docs is **deprecated** legacy BGP mode — do not use those pages.

## Where the docs are

| Topic | URL |
|---|---|
| Docs home (stable) | https://docs.cilium.io/en/stable |
| BGP Control Plane intro | https://docs.cilium.io/en/stable/network/bgp-control-plane/bgp-control-plane |
| BGP Control Plane resources (CRDs) | https://docs.cilium.io/en/stable/network/bgp-control-plane/bgp-control-plane-configuration |
| BGP troubleshooting | https://docs.cilium.io/en/stable/network/bgp-control-plane/bgp-control-plane-troubleshooting |
| BGP operation guide | https://docs.cilium.io/en/stable/network/bgp-control-plane/bgp-control-plane-operation |
| LB IPAM | https://docs.cilium.io/en/stable/network/lb-ipam |
| L2 announcements (beta) | https://docs.cilium.io/en/stable/network/l2-announcements |
| Network policy language | https://docs.cilium.io/en/stable/security/policy |
| Helm reference | https://docs.cilium.io/en/stable/helm-reference |
| Command cheatsheet | https://docs.cilium.io/en/stable/cheatsheet |
| Metrics reference (incl. BGP) | https://docs.cilium.io/en/stable/observability/metrics |
| Upgrade guide | https://docs.cilium.io/en/stable/operations/upgrade |
| Source | https://github.com/cilium/cilium |

## BGP Control Plane (v2)

BGP Control Plane makes Pod networks and/or Services reachable from
outside the cluster by advertising routes over BGP. It does **not**
program the datapath — never use it to establish reachability *within*
the cluster. Enabled with Helm value `bgpControlPlane.enabled=true`
(then `kubectl -n kube-system rollout restart ds/cilium`).

IPv4/IPv6 single-stack and dual-stack are supported, but only the
address families the agent is configured with can be advertised.

### The four CRDs

| CRD | Role |
|---|---|
| `CiliumBGPClusterConfig` | BGP instances + peers, applied cluster-wide by `nodeSelector` |
| `CiliumBGPPeerConfig` | Shared peer settings (timers, auth, multihop, graceful restart, transport, address families) |
| `CiliumBGPAdvertisement` | What gets advertised: PodCIDR, CiliumPodIPPool, Service VIPs, interface IPs |
| `CiliumBGPNodeConfigOverride` | Per-node overrides (router ID, local port/address/ASN) — its `metadata.name` must equal the node name, and instance/peer names must match the ClusterConfig |

The operator translates `CiliumBGPClusterConfig` into a per-node
`CiliumBGPNodeConfig` (auto-generated, source of truth for the node's
BGP config). The BGP speaker is GoBGP embedded in the Cilium agent.

```yaml
apiVersion: cilium.io/v2
kind: CiliumBGPClusterConfig
metadata:
  name: cilium-bgp
spec:
  nodeSelector:
    matchLabels:
      rack: rack0
  bgpInstances:
    - name: "instance-65000"
      localASN: 65000
      localPort: 179          # default: no listener (agent only dials out)
      peers:
        - name: "peer-65000-tor1"
          peerASN: 65000
          peerAddress: fd00:10:0:0::1
          peerConfigRef:
            name: "cilium-peer"
```

Key behaviors:

- **No listener by default** — instances only initiate connections (for
  coexistence with Bird etc.). Set `localPort` to accept incoming
  sessions; port 179 requires `CAP_NET_BIND_SERVICE` via
  `securityContext.capabilities.ciliumAgent` Helm value.
- **Auto-discovery** — `peers[].autoDiscovery.mode = "DefaultGateway"`
  peers with the node's default gateway (ToR) per address family. The
  ToR must run `bgp listen range` for dynamic neighbors with the same
  local ASN everywhere; link-local default gateways are not supported;
  one session per address family (multi-homing picks the lower-metric
  default route only).
- **MD5 auth** — `CiliumBGPPeerConfig.spec.authSecretRef` points at a
  Secret with key `password` in the BGP secrets namespace (default
  `kube-system`; `bgpControlPlane.secretNamespace.*` to change). TCP MD5
  signs the packet header — no NAT in front of the session, or it
  silently fails as `dial: i/o timeout`. A *missing* secret logs
  `Failed to fetch secret ... (will continue with empty password)` and
  proceeds unauthenticated.
- **Timers** — `connectRetryTimeSeconds` (default 120; jitter to
  [t, 2t)), `holdTimeSeconds` (90), `keepAliveTimeSeconds` (30). For
  datacenter/ToR setups: `holdTimeSeconds=9`, `keepAliveTimeSeconds=3`,
  `connectRetryTimeSeconds=5`. Minimums for fast failure detection:
  hold 3 / keepalive 1. **No BFD support yet** — timers are the only
  knob for link-failure detection.
- **Graceful restart** — `gracefulRestart.enabled=true` keeps the peer
  forwarding during agent restarts (`restartTimeSeconds`, default 120;
  must exceed agent boot time). Set it above image-pull time when
  upgrading.
- **ebgpMultihop** — TTL for eBGP sessions to route servers in other
  subnets.
- **families** — `afi`/`safi` pairs (`ipv4|ipv6` × `unicast` only) plus
  an `advertisements` label selector. **Without a matching selector no
  prefix is ever advertised** — the #1 "session established but no
  routes" cause.

### Advertisements

`CiliumBGPAdvertisement` resources are matched by the `advertisements`
selector in peer-config families (match on the resource's labels, e.g.
`advertise: bgp`). Attributes per entry: `communities`
(standard `65000:99`, well-known `no-export`, large `a:b:c`) and
`localPreference` (iBGP only, ignored for eBGP). Overlapping selectors
are supported since 1.18: communities union, local preference takes the
max.

| `advertisementType` | Advertises | Notes |
|---|---|---|
| `PodCIDR` | Node's allocated pod CIDR | Kubernetes/ClusterPool IPAM only. Per-node allocation, not the whole range |
| `CiliumPodIPPool` | CIDRs from selected pools | MultiPool IPAM; `selector.matchLabels` on pool labels |
| `Service` | Service VIPs | `service.addresses`: `LoadBalancerIP`, `ClusterIP`, `ExternalIP`; label selector picks services |
| `Interface` | IPs on a local interface (exact /32, /128) | e.g. loopback in multi-homing; interface must be up |

Service specifics:

- VIPs advertise as **exact /32 (or /128) routes**; aggregate with
  `service.aggregationLengthIPv4/IPv6` — but know the risk: aggregated
  prefixes covering unassigned addresses can blackhole/routing-loop
  (cilium#37623), and overlapping aggregations with different attributes
  are undefined (cilium#40585).
- With ECMP upstream, multiple nodes advertising the same VIP
  load-balances north/south traffic — check the router's ECMP path
  limit (e.g. Juniper) first.
- `externalTrafficPolicy: Local` (and `internalTrafficPolicy: Local`
  for ClusterIPs) withdraw the VIP when no local endpoints exist;
  `Cluster` advertises unconditionally. Aggregation lengths are ignored
  under `Local`.
- `loadBalancerClass` must be unset or `io.cilium/bgp-control-plane` for
  the ingress IPs to be announced.

### Router ID

`bgpControlPlane.routerIDAllocation.mode`: `default` (node's IPv4
address; on IPv6 single-stack, lower 32 bits of `cilium_host` MAC) or
`ip-pool` (allocate from `bgpControlPlane.routerIDAllocation.ipPool`).
Manual override per node via `CiliumBGPNodeConfigOverride`
`bgpInstances[].routerID`.

## LB IPAM

LB IPAM assigns IPs to `type: LoadBalancer` Services from
`CiliumLoadBalancerIPPool` resources — always enabled, dormant until the
first pool exists. It pairs with BGP control plane (or L2 announcements)
which do the actual advertising:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "blue-pool"
spec:
  blocks:
    - cidr: "10.0.10.0/24"
    - start: "20.0.20.100"   # start+stop are ONE block item
      stop: "20.0.20.200"
  serviceSelector:
    matchExpressions:
      - {key: color, operator: In, values: [blue, cyan]}
```

- `.spec.allowFirstLastIPs: No` reserves network/broadcast addresses
  (CIDR blocks only; ignored for /31, /32 and v6 equivalents).
- Pools with overlapping CIDRs: the last-added pool is marked
  `Conflicting` (`cilium.io/PoolConflict` condition) and stops
  allocating — check `kubectl get ippools` after any change.
- Updating a pool can reassign IPs and change service VIPs
  (cilium#40358) — plan changes.
- `disabled: true` drains a pool (no new allocations, existing kept).
- Services request specific IPs with annotation
  `lbipam.cilium.io/ips: "20.0.10.100,20.0.10.200"`; share VIPs across
  services with `lbipam.cilium.io/sharing-key` (cross-namespace sharing
  needs `lbipam.cilium.io/sharing-cross-namespace` on **both**
  services).
- Allocation failures surface as Service status conditions, e.g.
  `io.cilium/lb-ipam-request-satisfied` = False with reason `no_pool`.
- By default LB IPAM also serves services with no loadBalancerClass;
  set Helm `defaultLBServiceIPAM=none` to require an explicit class.

## L2 announcements (beta)

ARP/NDP-based alternative to BGP for flat office/campus networks
without BGP routing: one node per VIP answers ARP/NDP with its MAC and
north/south load-balances. Enabled with `l2announcements.enabled=true`
plus kube-proxy replacement; sized via `k8sClientRateLimit.qps/burst`
(sizing matters — the feature is API-server heavy).

- Policies: `CiliumL2AnnouncementPolicy` (`cilium.io/v2alpha1`) with
  `serviceSelector`, `nodeSelector`, `interfaces` (regex), and
  `externalIPs`/`loadBalancerIPs` toggles. Services need
  `loadBalancerClass` unset or `io.cilium/l2-announcer`.
- Incompatible with `externalTrafficPolicy: Local` (may announce IPs on
  nodes without pods → drops). No load balancing before traffic hits
  the cluster (one node answers ARP for an IP).

## Network policy essentials

- Policy resources: Kubernetes `NetworkPolicy`, `CiliumNetworkPolicy`
  (CNPs, namespaced) and `CiliumClusterwideNetworkPolicy` (CCNPs,
  cluster-scoped). The agent-API import path is deprecated since 1.18,
  removed in 1.19 — always go through Kubernetes resources.
- Enforcement is identity-based: select endpoints with
  `endpointSelector` (labels + `k8s:` namespace labels), allow by L3
  (labels, entities, CIDR, DNS/FQDN), L4 (ports, ICMP types, SNI), L7
  (HTTP, DNS). `deny` rules override allows. Empty/absent rules = allow
  all unless enforcement mode is set (namespace annotation
  `policy.cilium.io/...` or `--policy-enforcement`).
- Without a matching advertisement of *both* directions, default-deny
  bites: a pod selected by an ingress rule can no longer receive
  unlisted traffic (add egress rules for replies' dependent flows, DNS
  especially — use `toFQDNs` with `matchName`/`matchPattern`).
- `CiliumCIDRGroup` lets policies reference CIDR sets by name
  (`io.cilium.CIDRGroupName`).

## Troubleshooting BGP

Status conditions on `CiliumBGPClusterConfig`:

| Condition | Meaning |
|---|---|
| `cilium.io/NoMatchingNode` | `nodeSelector` matches nothing |
| `cilium.io/ConflictingClusterConfig` | another ClusterConfig selects the same node (multiple configs may NOT share nodes) |
| `cilium.io/MissingPeerConfigs` | a `peerConfigRef` name doesn't resolve |

On `CiliumBGPPeerConfig`: `cilium.io/MissingAuthSecret` — referenced
Secret missing (session then runs with an empty password).

Quick symptom → cause:

- **Resources applied, no `CiliumBGPNodeConfig` created** — operator
  logs (`subsys=bgp-cp-operator`), nodeSelector mismatch.
- **Session not established** — filter agent logs
  `grep bgp-control-plane`; look for `as number mismatch` (peerASN
  wrong), capability mismatches, wrong peer IP. Low-level failures
  (no route to peer, eBGP >1 hop without `ebgpMultihop`) may not log —
  use tcpdump/Wireshark.
- **Established but no routes advertised** — the peer-config
  `families[].advertisements` selector matches no
  `CiliumBGPAdvertisement` labels; or the Service/IPAM pool selector
  matches no objects.
- **`dial: i/o timeout`** — MD5 password mismatch or NAT in the path.
- **Routes flap on agent restarts** — enable graceful restart; check
  `restartTimeSeconds` vs agent boot time.

Operational commands (cilium-cli):

```bash
cilium bgp peers                       # session state per node (established? route counts?)
cilium bgp routes available ipv4 unicast
cilium bgp routes advertised ipv4 unicast
cilium config view | grep -i bgp       # agent feature flags
kubectl get ciliumbgpnodeconfigs       # per-node live BGP state (timers, route counts)
kubectl -n kube-system logs <agent> | grep bgp-control-plane
```

Node drain dance (avoid packet loss): `kubectl drain --ignore-daemonsets`
→ remove/flip the ClusterConfig nodeSelector label on the node → wait
for peer route withdrawal (immediate without graceful restart; stale
timer under RFC 8538; hold-time bound otherwise) → shut down.

## Gotchas

- **Default is silence** — no localPort listener and no advertisements
  until explicitly configured; "session up but nothing advertised" is
  almost always the families/advertisements selector.
- **No BFD** — tune timers for fast failure detection.
- **BGP ≠ datapath** — internal cluster reachability is not BGP's job.
- **Port 179 needs CAP_NET_BIND_SERVICE** on the cilium-agent container.
- **ClusterConfigs must not overlap node selection** — one config per
  node, enforced by the operator.
- **MD5 auth breaks behind NAT** and degrades silently to empty
  password when the Secret is missing — check for the fetch error log.
- **ECMP + VIPs**: router ECMP path limits; resilient hashing / Maglev
  help connection survival during node loss (Cluster policy only).
- **Upgrade with BGP**: pre-pull the agent image (preflight) — a slow
  pull can exceed `restartTimeSeconds` and cause route withdrawal.
