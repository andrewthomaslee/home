{
  inputs,
  self,
  ...
}: {
  # Consolidated OpenCode v2 VM test (single test, 3 size variants sm/md/lg).
  # Covers both opencode user shapes on one machine:
  # - alice: full desktop opencode (Electron + full dev toolset), headroom
  #   (MCP server + provider proxy), devenv/playwright/nixos/openrouter
  #   MCPs, GitHub MCP via the PAT method with a fake PAT file.
  # - netsa: the headless profile-netsa-agent (slim headroom, no desktop),
  #   GitHub MCP via the default OAuth method, all six Cloudflare remote
  #   MCPs, MDN, the home-manager native opencode web service
  #   (`opencode serve`), the global machine-context AGENTS.md (static
  #   eval asserts + deployed-file greps), and all eight reference
  #   bundles (linkFarm install + settings.references +
  #   external_directory permission rules).
  name = "opencode";
  globalTimeout = 10 * 60;

  nodes.machine = {
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [
      inputs.clan-core.nixosModules.clanCore
      self.nixosModules.default
    ];

    clan.core.settings = {
      directory = self;
      machine.name = "opencode-test";
    };

    networking.hostName = "opencode-test";
    networking.firewall.allowedTCPPorts = [22 4096];

    # clan-core's vars -> sops-nix deployment needs a key source; the VM
    # test machine is not in inventory so there is no provisioned age key.
    # Enabling sshd lets sops-nix derive its host key from the SSH host key.
    services.openssh.enable = true;
    security.sudo.wheelNeedsPassword = false;

    users.users = {
      alice = {
        isNormalUser = true;
        extraGroups = ["wheel"];
        linger = true;
      };
      netsa = {
        isNormalUser = true;
        extraGroups = ["wheel"];
        linger = true;
      };
    };

    home-manager = {
      useGlobalPkgs = false;
      useUserPackages = true;
      sharedModules = [
        inputs.plasma-manager.homeModules.plasma-manager
      ];
      users.alice = {
        imports = [
          self.homeModules.default
        ];
        home.stateVersion = "26.11";
        homeSpec.programs = {
          devenv = {
            enabled = true;
            # Non-interactive VM: exercise the devenv package + MCP
            # wiring, not the interactive auto-activation bash hook.
            autoActivate.enabled = false;
          };
          headroom = {
            enable = true;
            proxy = {
              enable = true;
              # Minimal smoke test: memory/learn pull embedding models at
              # startup, which blocks on a HF download in a fresh HOME.
              memory = false;
              learn = false;
            };
          };
          opencode = {
            enable = true;
            mcp = {
              # devenv MCP: exercises the wrapper (project discovery ->
              # pinned fallback project) and the generated devenv.yaml.
              devenv.enable = true;
              # PAT method with the fake file above as PAT source (defaults to
              # the clan var path /run/secrets/vars/shared/github-mcp/pat).
              github = {
                auth = "pat";
                patFile = "/etc/vm-github-pat";
              };
            };
          };
        };
      };
      # netsa: headless agent profile (headroom-slim + headless opencode),
      # plus the other mutually-exclusive GitHub auth branch (oauth remote
      # server, no secret), the opt-in Cloudflare/MDN remote MCP servers,
      # and the HM-native opencode web service. All six Cloudflare remote
      # MCP servers are enabled to exercise the opt-in path.
      users.netsa = {
        imports = [
          self.homeModules.profile-netsa-agent
        ];
        home.stateVersion = "26.11";
        # Second headroom proxy user on this VM: move off alice's default
        # 8787 port (the opencode module derives its providers.* proxy URL
        # from this option, so the override threads through automatically).
        homeSpec.programs.headroom.proxy.port = 8788;
        # HM-native opencode web service (replaces the hand-rolled
        # systemd user unit the KubeVirt agent image used pre-v2).
        programs.opencode.web = {
          enable = true;
          extraArgs = ["--hostname" "0.0.0.0" "--port" "4096"];
        };
        homeSpec.programs.opencode = {
          # Machine context: synthetic facter report + environment tag so
          # the generated global AGENTS.md has hardware + environment
          # lines to assert on (this VM's hostname has no real
          # machines/<host>/facter.json).
          machineContext = {
            environment = "vm (test)";
            facterReport = {
              hardware = {
                cpu = [
                  {
                    model_name = "VM Test CPU 9000";
                    units = 8;
                  }
                ];
                graphics_card = [
                  {
                    vendor = {name = "TestGPU";};
                    driver = "test";
                  }
                ];
                disk = [{model = "TestDisk 1TB";} {model = "TestDisk 2TB";}];
              };
              smbios.memory_device = [
                {
                  size = 8388608;
                  manufacturer = "TestRAM";
                }
              ];
            };
          };
          mcp = {
            cloudflare.enable = true;
            cloudflare-docs.enable = true;
            cloudflare-bindings.enable = true;
            cloudflare-builds.enable = true;
            cloudflare-browser.enable = true;
            cloudflare-containers.enable = true;
            # MDN Web Docs remote MCP server
            mdn.enable = true;
          };
          # References: all aliases on for this user — exercises
          # the linkFarm install (~/.config/opencode/references/<name>),
          # the settings.references entries, and the read +
          # external_directory permission rules.
          references = {
            nix-style.enable = true;
            flake-parts.enable = true;
            import-tree.enable = true;
            determinate.enable = true;
            home-manager.enable = true;
            clan-core.enable = true;
            devenv.enable = true;
            vm-tests.enable = true;
            cilium.enable = true;
            disko.enable = true;
            # Override one description to prove the option exists and
            # threads through to the generated config.
            nix-style.description = "VM-test override description";
          };
        };
      };
    };

    # Static eval-time assertions on the generated global AGENTS.md
    # (machine-context wiring): a failed assert throws during the
    # toplevel eval, before the VM even boots. The testScript greps below
    # mirror these against the deployed file.
    assertions = let
      agentsText = config.home-manager.users.netsa.xdg.configFile."opencode/AGENTS.md".text;
    in [
      {
        assertion = lib.hasInfix "Machine: opencode-test (NixOS" agentsText;
        message = "opencode VM test: global AGENTS.md is missing the Machine line";
      }
      {
        assertion = lib.hasInfix "Environment: vm (test)" agentsText;
        message = "opencode VM test: global AGENTS.md is missing the environment annotation";
      }
      {
        assertion = lib.hasInfix "CPU: VM Test CPU 9000, 8 threads" agentsText;
        message = "opencode VM test: global AGENTS.md is missing the synthetic facter CPU line";
      }
      {
        assertion = lib.hasInfix "Memory: 8 GiB (1x TestRAM DIMMs)" agentsText;
        message = "opencode VM test: global AGENTS.md is missing the synthetic facter memory line";
      }
      # Regression guard for the v2 root cause: opencode v2 does not
      # resolve the settings.instructions array, so it must stay unset.
      {
        assertion = !(config.home-manager.users.netsa.programs.opencode.settings ? instructions);
        message = "opencode VM test: settings.instructions is inert in opencode v2 — wire file instructions via the global AGENTS.md instead";
      }
    ];

    # MCP end-to-end probe for alice: drives `headroom mcp serve` over
    # stdio JSON-RPC exactly as opencode does (mcp.servers.headroom local
    # server) and exercises the CCR roundtrip: initialize -> tools/list ->
    # compress -> retrieve (verbatim roundtrip).
    environment = {
      systemPackages = with pkgs; [
        curl
        jq
        python3
      ];

      # GitHub MCP (PAT method) for alice: fake PAT deployed as a plain file
      # instead of the clan var (no sops secret exists in the repo), proving
      # the file -> env -> server-start wiring end to end. The "github-mcp"
      # clan var generator is derived automatically by
      # nixosModules/github-mcp from alice's mcp.github.auth = "pat" above.
      etc = {
        vm-github-pat.text = "ghp-fake-vm-test-pat";

        # devenv MCP end-to-end probe: drives the devenv-mcp-opencode
        # wrapper over stdio JSON-RPC exactly as opencode does (local
        # mcp.servers.devenv server). The cwd (/home/alice) has no
        # devenv.nix, so a successful initialize + tools/list PROVES the
        # wrapper fell back to the pinned ~/.config/devenv-agent project
        # and the server is up (its cache init runs in the background; the
        # search_packages / search_options tools are listed regardless,
        # so no full nixpkgs eval is needed for the handshake).
        "vm-devenv-probe.py".source = pkgs.writeText "vm-devenv-probe.py" ''
          import json
          import subprocess

          def send(proc, obj):
              proc.stdin.write((json.dumps(obj) + "\n").encode())
              proc.stdin.flush()

          def recv(proc, want_id):
              while True:
                  line = proc.stdout.readline()
                  if not line:
                      raise SystemExit("devenv MCP probe: server closed stdout")
                  msg = json.loads(line)
                  if msg.get("id") == want_id:
                      return msg

          proc = subprocess.Popen(
              ["devenv-mcp-opencode"],
              stdin=subprocess.PIPE, stdout=subprocess.PIPE,
              stderr=subprocess.PIPE,
          )
          try:
              send(proc, {
                  "jsonrpc": "2.0", "id": 1, "method": "initialize",
                  "params": {
                      "protocolVersion": "2024-11-05", "capabilities": {},
                      "clientInfo": {"name": "vm-probe", "version": "0"},
                  },
              })
              init = recv(proc, 1)
              assert "serverInfo" in init["result"], init
              send(proc, {"jsonrpc": "2.0", "method": "notifications/initialized"})

              send(proc, {"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
              tools = {t["name"] for t in recv(proc, 2)["result"]["tools"]}
              assert {"search_packages", "search_options"} <= tools, tools

              print("DEVENV_MCP_OK")
          except SystemExit:
              err = proc.stderr.read().decode()
              print("DEVENV_STDERR:", err[-600:])
              raise
          finally:
              try:
                  proc.stdin.close()
              except Exception:
                  pass
              proc.terminate()
        '';

        "vm-mcp-probe.py".source = pkgs.writeText "vm-mcp-probe.py" ''
          import json
          import subprocess
          import sys

          PROXY = "http://127.0.0.1:8787"

          def send(proc, obj):
              proc.stdin.write((json.dumps(obj) + "\n").encode())
              proc.stdin.flush()

          def recv(proc, want_id):
              while True:
                  line = proc.stdout.readline()
                  if not line:
                      raise SystemExit("MCP probe: server closed stdout")
                  msg = json.loads(line)
                  if msg.get("id") == want_id:
                      return msg

          def call(proc, id, name, arguments):
              send(proc, {
                  "jsonrpc": "2.0", "id": id, "method": "tools/call",
                  "params": {"name": name, "arguments": arguments},
              })
              return recv(proc, id)

          proc = subprocess.Popen(
              ["headroom", "mcp", "serve", "--proxy-url", PROXY],
              stdin=subprocess.PIPE, stdout=subprocess.PIPE,
              stderr=subprocess.DEVNULL,
          )
          try:
              # 1. initialize
              send(proc, {
                  "jsonrpc": "2.0", "id": 1, "method": "initialize",
                  "params": {
                      "protocolVersion": "2024-11-05", "capabilities": {},
                      "clientInfo": {"name": "vm-probe", "version": "0"},
                  },
              })
              init = recv(proc, 1)
              assert init["result"]["serverInfo"]["name"] == "headroom", init
              send(proc, {"jsonrpc": "2.0", "method": "notifications/initialized"})

              # tools/list
              send(proc, {"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
              tools = {t["name"] for t in recv(proc, 2)["result"]["tools"]}
              assert {"headroom_compress", "headroom_retrieve", "headroom_stats"} <= tools, tools

              # compress -> hash
              content = "\n".join(f"line {i}: some tool output content" for i in range(200))
              resp = call(proc, 3, "headroom_compress", {"content": content})
              body = json.loads(resp["result"]["content"][0]["text"])
              assert "error" not in body, body
              hash_key = body["hash"]
              assert hash_key and body["original_tokens"] >= body["compressed_tokens"], body

              # retrieve -> verbatim roundtrip
              resp = call(proc, 4, "headroom_retrieve", {"hash": hash_key})
              retrieved = json.loads(resp["result"]["content"][0]["text"])
              assert retrieved.get("original_content") == content, "retrieve mismatch"

              print("MCP_E2E_OK")
          finally:
              try:
                  proc.stdin.close()
              except Exception:
                  pass
              proc.terminate()

          # --- Playwright MCP probe: drive the hermetic nixpkgs
          # playwright-mcp server over stdio JSON-RPC exactly as opencode
          # does (mcp.servers.playwright local server). initialize ->
          # tools/list only; no tool call, so no browser/X server is needed.
          proc2 = subprocess.Popen(
              ["playwright-mcp", "--headless"],
              stdin=subprocess.PIPE, stdout=subprocess.PIPE,
              stderr=subprocess.DEVNULL,
          )
          try:
              send(proc2, {
                  "jsonrpc": "2.0", "id": 11, "method": "initialize",
                  "params": {
                      "protocolVersion": "2024-11-05", "capabilities": {},
                      "clientInfo": {"name": "vm-probe", "version": "0"},
                  },
              })
              init2 = recv(proc2, 11)
              assert "serverInfo" in init2["result"], init2
              send(proc2, {"jsonrpc": "2.0", "method": "notifications/initialized"})

              send(proc2, {"jsonrpc": "2.0", "id": 12, "method": "tools/list"})
              tools2 = {t["name"] for t in recv(proc2, 12)["result"]["tools"]}
              assert {"browser_navigate", "browser_snapshot", "browser_click"} <= tools2, tools2

              print("PLAYWRIGHT_MCP_OK")
          finally:
              try:
                  proc2.stdin.close()
              except Exception:
                  pass
              proc2.terminate()

          # --- GitHub MCP probe (PAT method): drive the
          # github-mcp-server-opencode wrapper over stdio JSON-RPC exactly as
          # opencode does (mcp.servers.github local server). The upstream
          # server exits immediately when GITHUB_PERSONAL_ACCESS_TOKEN is
          # unset, so a successful initialize/tools/list PROVES the wrapper
          # read the PAT file and exported the env var (no network needed;
          # the fake PAT is only rejected on actual API calls).
          proc3 = subprocess.Popen(
              ["github-mcp-server-opencode"],
              stdin=subprocess.PIPE, stdout=subprocess.PIPE,
              stderr=subprocess.DEVNULL,
          )
          try:
              send(proc3, {
                  "jsonrpc": "2.0", "id": 21, "method": "initialize",
                  "params": {
                      "protocolVersion": "2024-11-05", "capabilities": {},
                      "clientInfo": {"name": "vm-probe", "version": "0"},
                  },
              })
              init3 = recv(proc3, 21)
              assert init3["result"]["serverInfo"]["name"] == "github-mcp-server", init3
              send(proc3, {"jsonrpc": "2.0", "method": "notifications/initialized"})

              send(proc3, {"jsonrpc": "2.0", "id": 22, "method": "tools/list"})
              tools3 = {t["name"] for t in recv(proc3, 22)["result"]["tools"]}
              assert {"get_me", "list_issues", "create_repository", "get_file_contents"} <= tools3, tools3

              print("GITHUB_MCP_OK")
          finally:
              try:
                  proc3.stdin.close()
              except Exception:
                  pass
              proc3.terminate()
        '';

        # Headroom MCP probe for netsa (slim build, proxy on 8788): drives
        # `headroom mcp serve` over stdio JSON-RPC exactly as opencode does
        # and exercises the CCR roundtrip (compress -> retrieve).
        "vm-web-mcp-probe.py".source = pkgs.writeText "vm-web-mcp-probe.py" ''
          import json
          import subprocess
          import sys

          PROXY = "http://127.0.0.1:8788"

          def send(proc, obj):
              proc.stdin.write((json.dumps(obj) + "\n").encode())
              proc.stdin.flush()

          def recv(proc, want_id):
              while True:
                  line = proc.stdout.readline()
                  if not line:
                      raise SystemExit("MCP probe: server closed stdout")
                  msg = json.loads(line)
                  if msg.get("id") == want_id:
                      return msg

          def call(proc, id, name, arguments):
              send(proc, {
                  "jsonrpc": "2.0", "id": id, "method": "tools/call",
                  "params": {"name": name, "arguments": arguments},
              })
              return recv(proc, id)

          proc = subprocess.Popen(
              ["headroom", "mcp", "serve", "--proxy-url", PROXY],
              stdin=subprocess.PIPE, stdout=subprocess.PIPE,
              stderr=subprocess.DEVNULL,
          )
          try:
              # 1. initialize
              send(proc, {
                  "jsonrpc": "2.0", "id": 1, "method": "initialize",
                  "params": {
                      "protocolVersion": "2024-11-05", "capabilities": {},
                      "clientInfo": {"name": "vm-web-probe", "version": "0"},
                  },
              })
              init = recv(proc, 1)
              assert init["result"]["serverInfo"]["name"] == "headroom", init
              send(proc, {"jsonrpc": "2.0", "method": "notifications/initialized"})

              # tools/list
              send(proc, {"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
              tools = {t["name"] for t in recv(proc, 2)["result"]["tools"]}
              assert {"headroom_compress", "headroom_retrieve", "headroom_stats"} <= tools, tools

              # compress -> hash
              content = "\n".join(f"line {i}: agent web tool test payload" for i in range(200))
              resp = call(proc, 3, "headroom_compress", {"content": content})
              body = json.loads(resp["result"]["content"][0]["text"])
              assert "error" not in body, body
              hash_key = body["hash"]
              assert hash_key and body["original_tokens"] >= body["compressed_tokens"], body

              # retrieve -> verbatim roundtrip
              resp = call(proc, 4, "headroom_retrieve", {"hash": hash_key})
              retrieved = json.loads(resp["result"]["content"][0]["text"])
              assert retrieved.get("original_content") == content, "retrieve mismatch"

              print("MCP_WEB_E2E_OK")
          finally:
              try:
                  proc.stdin.close()
              except Exception:
                  pass
              proc.terminate()
        '';
      };
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")

    # 1. Verify binaries are installed on PATH (alice)
    machine.succeed("su - alice -c 'headroom --version'")
    machine.succeed("su - alice -c 'opencode --version'")

    # 2. Verify Home-Manager generated ~/.config/opencode/opencode.json in
    # native V2 shape: mcp.servers.*, plugins, providers.*.settings,
    # permissions array, agents.title.model.
    machine.succeed("su - alice -c 'test -f ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .mcp.servers.headroom ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .mcp.servers.openrouter ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .mcp.servers.openrouter.url ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .mcp.servers.playwright ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .mcp.servers.playwright.command ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'playwright-mcp --version'")
    # V2 native provider proxy override (was provider.<p>.options.baseURL in V1)
    machine.succeed("su - alice -c 'jq -e .providers.deepseek ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .providers.deepseek.settings.baseURL ~/.config/opencode/opencode.json'")
    # V2 ordered permissions array (was the permission.<tool> map in V1)
    machine.succeed("su - alice -c 'jq -e \".permissions | length > 0\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e \"any(.permissions[]; .action == \\\"read\\\" and .resource == \\\"/nix/store/**\\\" and .effect == \\\"allow\\\")\" ~/.config/opencode/opencode.json'")
    # small_model V1 field replaced by the native title-agent model
    machine.succeed("su - alice -c 'jq -e .agents.title.model ~/.config/opencode/opencode.json'")
    # V2 native plugins list (was plugin in V1): cc-safety-net is on by default
    machine.succeed("su - alice -c 'jq -e \".plugins | length > 0\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e \".plugins[0] | endswith(\\\"cc-safety-net/dist/index.js\\\")\" ~/.config/opencode/opencode.json'")

    # 2c. Verify the GitHub MCP server (PAT method) is enabled for alice:
    # binary on PATH, local mcp.servers entry with the wrapper command, and
    # the wrapper can read the PAT file.
    machine.succeed("su - alice -c 'github-mcp-server --version'")
    machine.succeed("su - alice -c 'test -x ~/.nix-profile/bin/github-mcp-server-opencode || test -x /run/current-system/sw/bin/github-mcp-server-opencode || which github-mcp-server-opencode'")
    machine.succeed("su - alice -c 'jq -e \".mcp.servers.github.type == \\\"local\\\"\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .mcp.servers.github.command ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'cat /etc/vm-github-pat | grep -q ghp-fake-vm-test-pat'")

    # 2d. Machine context: the global AGENTS.md is generated for this
    # machine (machineContext is on by default), deployed as a store
    # symlink carrying the Machine line.
    machine.succeed("su - alice -c 'test -L ~/.config/opencode/AGENTS.md'")
    machine.succeed("su - alice -c 'grep -q \"Machine: opencode-test (NixOS\" ~/.config/opencode/AGENTS.md'")

    # 2c+. Verify devenv: the flake-package CLI on PATH, the local
    # mcp.servers.devenv entry with the wrapper command, and the pinned
    # fallback project generated by the devenv home module + opencode module.
    machine.succeed("su - alice -c 'devenv --version'")
    machine.succeed("su - alice -c 'jq -e \".mcp.servers.devenv.type == \\\"local\\\"\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .mcp.servers.devenv.command ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'grep -q devenv-mcp-opencode ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'test -f ~/.config/devenv-agent/devenv.yaml'")
    machine.succeed("su - alice -c 'test -f ~/.config/devenv-agent/devenv.nix'")
    # The wrapper binary is on PATH (also installed by the opencode module).
    machine.succeed("su - alice -c 'test -x ~/.nix-profile/bin/devenv-mcp-opencode || test -x /run/current-system/sw/bin/devenv-mcp-opencode || which devenv-mcp-opencode'")

    # 3. Verify and start alice's headroom-proxy user unit. The HM
    # activation can race the user-manager boot (linger): the daemon may
    # reach default.target before the unit files land, so deterministically
    # reload + start rather than relying on luck.
    machine.succeed("su - alice -c 'test -f ~/.config/systemd/user/headroom-proxy.service'")
    machine.succeed(
      "su - alice -c 'export XDG_RUNTIME_DIR=/run/user/1000"
      " DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus;"
      " systemctl --user daemon-reload'"
    )
    machine.succeed(
      "su - alice -c 'export XDG_RUNTIME_DIR=/run/user/1000"
      " DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus;"
      " systemctl --user start headroom-proxy.service'"
    )

    # Verify Headroom proxy is running and responds to healthcheck
    machine.wait_until_succeeds("curl -sf http://127.0.0.1:8787/livez", timeout=120)

    # 4. Verify Headroom MCP server CLI responds
    machine.succeed("su - alice -c 'headroom mcp --help'")

    # 5. End-to-end MCP check for alice: drive headroom mcp serve,
    # playwright-mcp and the github-mcp-server wrapper exactly as opencode
    # would (stdio JSON-RPC): CCR roundtrip through the running proxy,
    # tools/list for playwright, and PAT-file -> env proof for github.
    machine.succeed("su - alice -c 'python3 /etc/vm-mcp-probe.py'")

    # 6. devenv MCP end-to-end check: wrapper -> pinned fallback project
    # (cwd /home/alice has no devenv.nix) -> initialize + tools/list.
    machine.succeed("su - alice -c 'python3 /etc/vm-devenv-probe.py'")

    # ---- netsa: headless profile (headroom-slim, no desktop), oauth
    # github, Cloudflare/MDN remotes, HM-native web service.
    machine.wait_for_unit("user@1001.service")
    machine.wait_until_succeeds(
      "su - netsa -c 'test -f ~/.config/opencode/opencode.json'", timeout=60
    )
    machine.succeed("su - netsa -c 'opencode --version'")

    # 7. Verify netsa's GitHub MCP uses the default oauth method (remote
    # server, no secret) — the other mutually-exclusive auth branch.
    machine.succeed("su - netsa -c 'jq -e \".mcp.servers.github.type == \\\"remote\\\"\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - netsa -c 'jq -e \".mcp.servers.github.url == \\\"https://api.githubcopilot.com/mcp/\\\"\" ~/.config/opencode/opencode.json'")

    # 7+. Machine context for netsa: the global AGENTS.md store symlink
    # carries the machine, environment and synthetic hardware lines (the
    # runtime mirror of the static eval assertions above).
    machine.succeed("su - netsa -c 'test -L ~/.config/opencode/AGENTS.md'")
    machine.succeed("su - netsa -c 'grep -q \"Machine: opencode-test (NixOS\" ~/.config/opencode/AGENTS.md'")
    machine.succeed("su - netsa -c 'grep -q \"Environment: vm (test)\" ~/.config/opencode/AGENTS.md'")
    machine.succeed("su - netsa -c 'grep -q \"CPU: VM Test CPU 9000, 8 threads\" ~/.config/opencode/AGENTS.md'")
    machine.succeed("su - netsa -c 'grep -q \"GPU: TestGPU, driver test\" ~/.config/opencode/AGENTS.md'")
    machine.succeed("su - netsa -c 'grep -q \"Memory: 8 GiB (1x TestRAM DIMMs)\" ~/.config/opencode/AGENTS.md'")
    machine.succeed("su - netsa -c 'grep -q \"Disk: TestDisk 1TB, TestDisk 2TB\" ~/.config/opencode/AGENTS.md'")

    # 7++. Verify netsa's six Cloudflare remote MCP servers are generated
    # with the correct URLs (enabled via the opt-in toggles). Hyphenated
    # keys need bracket notation in jq ("." would parse as subtraction).
    machine.succeed("su - netsa -c 'jq -e \"[.mcp.servers.cloudflare.type, .mcp.servers[\\\"cloudflare-docs\\\"].type, .mcp.servers[\\\"cloudflare-bindings\\\"].type, .mcp.servers[\\\"cloudflare-builds\\\"].type, .mcp.servers[\\\"cloudflare-browser\\\"].type, .mcp.servers[\\\"cloudflare-containers\\\"].type] | all(. == \\\"remote\\\")\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - netsa -c 'jq -e \"[.mcp.servers.cloudflare.url, .mcp.servers[\\\"cloudflare-docs\\\"].url, .mcp.servers[\\\"cloudflare-bindings\\\"].url, .mcp.servers[\\\"cloudflare-builds\\\"].url, .mcp.servers[\\\"cloudflare-browser\\\"].url, .mcp.servers[\\\"cloudflare-containers\\\"].url] == [\\\"https://mcp.cloudflare.com/mcp\\\", \\\"https://docs.mcp.cloudflare.com/mcp\\\", \\\"https://bindings.mcp.cloudflare.com/mcp\\\", \\\"https://builds.mcp.cloudflare.com/mcp\\\", \\\"https://browser.mcp.cloudflare.com/mcp\\\", \\\"https://containers.mcp.cloudflare.com/mcp\\\"]\" ~/.config/opencode/opencode.json'")

    # 8. Verify netsa's MDN Web Docs remote MCP server entry.
    machine.succeed("su - netsa -c 'jq -e \".mcp.servers.mdn.type == \\\"remote\\\"\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - netsa -c 'jq -e \".mcp.servers.mdn.url == \\\"https://mcp.mdn.mozilla.net/\\\"\" ~/.config/opencode/opencode.json'")

    # 8+. Verify references: all ten aliases installed as symlinks
    # under ~/.config/opencode/references, advertised in
    # settings.references (path + non-empty description; the nix-style
    # description carries the VM-test override), and the read +
    # external_directory permission rules present.
    machine.succeed("su - netsa -c 'test -d ~/.config/opencode/references'")
    machine.succeed("su - netsa -c 'test -f ~/.config/opencode/references/nix-style/index.md'")
    machine.succeed("su - netsa -c 'test -f ~/.config/opencode/references/flake-parts/index.md'")
    machine.succeed("su - netsa -c 'test -f ~/.config/opencode/references/import-tree/index.md'")
    machine.succeed("su - netsa -c 'test -f ~/.config/opencode/references/determinate/index.md'")
    machine.succeed("su - netsa -c 'test -f ~/.config/opencode/references/home-manager/index.md'")
    machine.succeed("su - netsa -c 'test -f ~/.config/opencode/references/clan-core/index.md'")
    machine.succeed("su - netsa -c 'test -f ~/.config/opencode/references/devenv/index.md'")
    machine.succeed("su - netsa -c 'test -f ~/.config/opencode/references/vm-tests/index.md'")
    machine.succeed("su - netsa -c 'test -f ~/.config/opencode/references/cilium/index.md'")
    machine.succeed("su - netsa -c 'test -f ~/.config/opencode/references/disko/index.md'")
    machine.succeed("su - netsa -c 'jq -e \".references | keys == [\\\"cilium\\\", \\\"clan-core\\\", \\\"determinate\\\", \\\"devenv\\\", \\\"disko\\\", \\\"flake-parts\\\", \\\"home-manager\\\", \\\"import-tree\\\", \\\"nix-style\\\", \\\"vm-tests\\\"]\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - netsa -c 'jq -e \".references[\\\"nix-style\\\"].path == \\\"~/.config/opencode/references/nix-style\\\"\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - netsa -c 'jq -e \".references[\\\"nix-style\\\"].description == \\\"VM-test override description\\\"\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - netsa -c 'jq -e \"[.references[] | .description | length > 0] | all\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - netsa -c 'jq -e \"any(.permissions[]; .action == \\\"external_directory\\\" and .resource == \\\"/home/netsa/.config/opencode/references/**\\\" and .effect == \\\"allow\\\")\" ~/.config/opencode/opencode.json'")
    # Content smoke check: each installed index.md starts with its topic
    # title (the symlink resolves into the store copy of the repo tree).
    machine.succeed("su - netsa -c 'head -1 ~/.config/opencode/references/nix-style/index.md | grep -q \"# nix-style\"'")
    machine.succeed("su - netsa -c 'head -1 ~/.config/opencode/references/vm-tests/index.md | grep -q \"# vm-tests\"'")
    machine.succeed("su - netsa -c 'head -1 ~/.config/opencode/references/cilium/index.md | grep -q \"# cilium\"'")
    machine.succeed("su - netsa -c 'head -1 ~/.config/opencode/references/disko/index.md | grep -q \"# disko\"'")

    # 9. Verify and start netsa's headroom proxy (slim build, port 8788)
    # and its HM-native opencode web service.
    machine.succeed("su - netsa -c 'test -f ~/.config/systemd/user/headroom-proxy.service'")
    machine.succeed(
      "su - netsa -c 'export XDG_RUNTIME_DIR=/run/user/1001"
      " DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus;"
      " systemctl --user daemon-reload'"
    )
    machine.succeed(
      "su - netsa -c 'export XDG_RUNTIME_DIR=/run/user/1001"
      " DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus;"
      " systemctl --user start headroom-proxy.service'"
    )
    machine.wait_until_succeeds("curl -sf http://127.0.0.1:8788/livez", timeout=120)

    # HM-native opencode web service: generated unit, start it, verify the
    # server responds over HTTP with the OpenCode HTML title.
    machine.succeed("su - netsa -c 'test -f ~/.config/systemd/user/opencode-web.service'")
    machine.succeed(
      "su - netsa -c 'export XDG_RUNTIME_DIR=/run/user/1001"
      " DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus;"
      " systemctl --user start opencode-web.service'"
    )
    machine.wait_until_succeeds("curl -sf http://127.0.0.1:4096 | grep -i '<title>OpenCode</title>'", timeout=120)
    machine.succeed("curl -sf -I http://127.0.0.1:4096 | grep -i 'Content-Type: text/html'")

    # 10. Headroom MCP end-to-end compression & retrieval probe for netsa
    # (slim build, proxy on 8788).
    machine.succeed("su - netsa -c 'python3 /etc/vm-web-mcp-probe.py'")
  '';
}
