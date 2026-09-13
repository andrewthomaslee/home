{
  inputs,
  self,
  pkgs,
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

    users.users.alice = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      linger = true;
    };

    environment.systemPackages = with pkgs; [
      curl
      jq
      python3
    ];

    home-manager.useGlobalPkgs = false;
    home-manager.useUserPackages = true;
    home-manager.sharedModules = [
      inputs.plasma-manager.homeModules.plasma-manager
    ];
    home-manager.users.alice = {
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
        opencode.enable = true;
      };
    };

    # MCP end-to-end probe: drives `headroom mcp serve` over stdio
    # JSON-RPC exactly as opencode does (mcp.headroom local server) and
    # exercises the CCR roundtrip: initialize -> tools/list ->
    # compress -> retrieve (verbatim roundtrip).
    environment.etc."vm-mcp-probe.py".source = pkgs.writeText "vm-mcp-probe.py" ''
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
    '';
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

    # 5. End-to-end MCP check: drive headroom mcp serve exactly as
    # opencode would (stdio JSON-RPC) and exercise the CCR roundtrip
    # (compress -> retrieve verbatim) through the running proxy.
    machine.succeed("su - alice -c 'python3 /etc/vm-mcp-probe.py'")
  '';
}
