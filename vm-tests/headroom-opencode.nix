{
  inputs,
  self,
  ...
}: {
  name = "headroom-opencode";
  globalTimeout = 5 * 60;

  nodes.machine = {pkgs, ...}: {
    imports = [
      inputs.clan-core.nixosModules.clanCore
      self.nixosModules.default
    ];

    clan.core.settings = {
      directory = self;
      machine.name = "headroom-test";
    };

    networking.hostName = "headroom-test";

    # clan-core's vars -> sops-nix deployment needs a key source; the VM
    # test machine is not in inventory so there is no provisioned age key.
    # Enabling sshd lets sops-nix derive its host key from the SSH host key.
    services.openssh.enable = true;

    users.users = {
      alice = {
        isNormalUser = true;
        extraGroups = ["wheel"];
        linger = true;
      };
      bob = {
        isNormalUser = true;
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
            # PAT method with the fake file above as PAT source (defaults to
            # the clan var path /run/secrets/vars/shared/github-mcp/pat).
            mcp.github.auth = "pat";
            mcp.github.patFile = "/etc/vm-github-pat";
          };
        };
      };
      # bob: GitHub MCP with the default method (oauth remote server, no
      # secret) to exercise the other mutually-exclusive auth branch —
      # enableGithubMcp itself also defaults to true. All six Cloudflare
      # remote MCP servers are enabled to exercise the opt-in path.
      users.bob = {
        imports = [
          self.homeModules.default
        ];
        home.stateVersion = "26.11";
        homeSpec.programs.opencode = {
          enable = true;
          enableDesktop = false;
          fullDevTools = false;
          # Morph Fast Apply with the fake key file above: exercises the
          # morph-api-key clan var generator declaration, the opencode
          # wrapper (MORPH_API_KEY export) and the plugin entry.
          plugins = {
            morph-fast-apply = {
              enable = true;
              apiKeyFile = "/etc/vm-morph-key";
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
        };
      };
    };

    # MCP end-to-end probe: drives `headroom mcp serve` over stdio
    # JSON-RPC exactly as opencode does (mcp.headroom local server) and
    # exercises the CCR roundtrip: initialize -> tools/list ->
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
      # nixosModules/github-mcp from alice's githubMcpAuth = "pat" below.
      etc = {
        vm-github-pat.text = "ghp-fake-vm-test-pat";
        # Fake Morph API key: proves the opencode wrapper -> MORPH_API_KEY env
        # -> plugin wiring end to end (same pattern as the github PAT above;
        # the clan var generator stays inert because apiKeyFile is overridden).
        vm-morph-key.text = "morph-fake-vm-test-key";
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
          # does (mcp.playwright local server). initialize -> tools/list
          # only; no tool call, so no browser/X server is needed.
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
          # opencode does (mcp.github local server). The upstream server exits
          # immediately when GITHUB_PERSONAL_ACCESS_TOKEN is unset, so a
          # successful initialize/tools/list PROVES the wrapper read the PAT
          # file and exported the env var (no network needed; the fake PAT is
          # only rejected on actual API calls).
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
      };
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")

    # 1. Verify binaries are installed on PATH
    machine.succeed("su - alice -c 'headroom --version'")
    machine.succeed("su - alice -c 'opencode --version'")

    # 2. Verify Home-Manager generated ~/.config/opencode/opencode.json with Headroom MCP & Plugin
    machine.succeed("su - alice -c 'test -f ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .mcp.headroom ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .plugin ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .provider.deepseek ~/.config/opencode/opencode.json'")

    # 2b. Verify the OpenRouter (remote) and Playwright (local) MCP
    # servers are enabled in the generated opencode config.
    machine.succeed("su - alice -c 'jq -e .mcp.openrouter ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .mcp.openrouter.url ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .mcp.playwright ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .mcp.playwright.command ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'playwright-mcp --version'")

    # 2c. Verify the GitHub MCP server (PAT method) is enabled for alice:
    # binary on PATH, local mcp entry with the wrapper command, and the
    # wrapper can read the PAT file.
    machine.succeed("su - alice -c 'github-mcp-server --version'")
    machine.succeed("su - alice -c 'test -x ~/.nix-profile/bin/github-mcp-server-opencode || test -x /run/current-system/sw/bin/github-mcp-server-opencode || which github-mcp-server-opencode'")
    machine.succeed("su - alice -c 'jq -e \".mcp.github.type == \\\"local\\\"\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'jq -e .mcp.github.command ~/.config/opencode/opencode.json'")
    machine.succeed("su - alice -c 'cat /etc/vm-github-pat | grep -q ghp-fake-vm-test-pat'")

    # 2d. Verify bob's GitHub MCP uses the default oauth method (remote
    # server, no secret) — the other mutually-exclusive auth branch.
    machine.wait_for_unit("user@1001.service")
    machine.wait_until_succeeds(
      "su - bob -c 'test -f ~/.config/opencode/opencode.json'", timeout=60
    )
    machine.succeed("su - bob -c 'jq -e \".mcp.github.type == \\\"remote\\\"\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - bob -c 'jq -e \".mcp.github.url == \\\"https://api.githubcopilot.com/mcp/\\\"\" ~/.config/opencode/opencode.json'")

    # 2d+. Verify bob's Morph plugin: store-path entry in the plugin list
    # and the opencode wrapper exporting MORPH_API_KEY from the key file.
    machine.succeed(
      # HM wraps cfg.package once more (wrapProgram): bin/opencode is a
      # shim exec'ing the hidden .opencode-wrapped symlink, which resolves
      # to the morph-key wrapper exporting MORPH_API_KEY.
      "su - bob -c 'inner=$(dirname $(readlink -f $(which opencode)))/.opencode-wrapped; test -e \"$inner\" && grep -q MORPH_API_KEY \"$(readlink -f \"$inner\")\"'"
    )
    machine.succeed("su - bob -c 'cat /etc/vm-morph-key | grep -q morph-fake-vm-test-key'")

    # 2e. Verify bob's six Cloudflare remote MCP servers are generated
    # with the correct URLs (enabled via the opt-in toggles). Hyphenated
    # keys need bracket notation in jq ("." would parse as subtraction).
    machine.succeed("su - bob -c 'jq -e \"[.mcp.cloudflare.type, .mcp[\\\"cloudflare-docs\\\"].type, .mcp[\\\"cloudflare-bindings\\\"].type, .mcp[\\\"cloudflare-builds\\\"].type, .mcp[\\\"cloudflare-browser\\\"].type, .mcp[\\\"cloudflare-containers\\\"].type] | all(. == \\\"remote\\\")\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - bob -c 'jq -e \"[.mcp.cloudflare.url, .mcp[\\\"cloudflare-docs\\\"].url, .mcp[\\\"cloudflare-bindings\\\"].url, .mcp[\\\"cloudflare-builds\\\"].url, .mcp[\\\"cloudflare-browser\\\"].url, .mcp[\\\"cloudflare-containers\\\"].url] == [\\\"https://mcp.cloudflare.com/mcp\\\", \\\"https://docs.mcp.cloudflare.com/mcp\\\", \\\"https://bindings.mcp.cloudflare.com/mcp\\\", \\\"https://builds.mcp.cloudflare.com/mcp\\\", \\\"https://browser.mcp.cloudflare.com/mcp\\\", \\\"https://containers.mcp.cloudflare.com/mcp\\\"]\" ~/.config/opencode/opencode.json'")

    # 2f. Verify bob's MDN Web Docs remote MCP server entry.
    machine.succeed("su - bob -c 'jq -e \".mcp.mdn.type == \\\"remote\\\"\" ~/.config/opencode/opencode.json'")
    machine.succeed("su - bob -c 'jq -e \".mcp.mdn.url == \\\"https://mcp.mdn.mozilla.net/\\\"\" ~/.config/opencode/opencode.json'")

    # 3. Verify the headroom-proxy user unit exists and start it.
    # The HM activation can race the user-manager boot (linger): the
    # daemon may reach default.target before the unit files land, so
    # deterministically reload + start rather than relying on luck.
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

    # 5. End-to-end MCP check: drive headroom mcp serve, playwright-mcp
    # and the github-mcp-server wrapper exactly as opencode would (stdio
    # JSON-RPC): CCR roundtrip through the running proxy, tools/list for
    # playwright, and PAT-file -> env proof for github.
    machine.succeed("su - alice -c 'python3 /etc/vm-mcp-probe.py'")
  '';
}
