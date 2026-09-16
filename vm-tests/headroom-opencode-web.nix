{
  inputs,
  self,
  pkgs,
  ...
}: {
  name = "headroom-opencode-web";
  globalTimeout = 5 * 60;

  nodes.machine = {pkgs, ...}: {
    imports = [
      inputs.clan-core.nixosModules.clanCore
      self.nixosModules.default
    ];

    clan.core.settings = {
      directory = self;
      machine.name = "kubevirt-web-test";
    };

    networking.hostName = "kubevirt-web-test";
    networking.firewall.allowedTCPPorts = [22 4096];

    # clan-core's vars -> sops-nix deployment needs a key source; the VM
    # test machine is not in inventory so there is no provisioned age key.
    # Enabling sshd lets sops-nix derive its host key from the SSH host key.
    services.openssh.enable = true;

    environment.systemPackages = with pkgs; [
      curl
      jq
      python3
    ];

    # Headless netsa user configured as an AI agent
    users.users.netsa = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      linger = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOb4q9LWJR54SzRkfmsA5KWA5/SDEG853oFC8TVilCW/"
      ];
    };
    security.sudo.wheelNeedsPassword = false;

    home-manager.useGlobalPkgs = false;
    home-manager.useUserPackages = true;
    home-manager.sharedModules = [
      inputs.plasma-manager.homeModules.plasma-manager
    ];
    home-manager.users.netsa = self.homeModules.profile-netsa-agent;

    # OpenCode Web server unit for netsa user
    systemd.user.services.opencode-web = {
      description = "OpenCode Web Server (Headless Agent)";
      wantedBy = ["default.target"];
      after = ["network.target" "headroom-proxy.service"];
      environment = {
        HOME = "/home/netsa";
      };
      serviceConfig = {
        ExecStart = "${inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode}/bin/opencode serve --port 4096 --hostname 0.0.0.0";
        Restart = "always";
        RestartSec = 3;
      };
    };

    # MCP end-to-end probe: drives `headroom mcp serve` over stdio
    # JSON-RPC and exercises the CCR roundtrip (compress -> retrieve).
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

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")

    # 1. Verify developer toolings are available on PATH for netsa
    machine.succeed("su - netsa -c 'headroom --version'")
    machine.succeed("su - netsa -c 'opencode --version'")
    machine.succeed("su - netsa -c 'nvim --version'")
    machine.succeed("su - netsa -c 'tmux -V'")
    machine.succeed("su - netsa -c 'git --version'")

    # 2. Verify Home-Manager generated ~/.config/opencode/opencode.json with Headroom MCP & Plugin
    machine.succeed("su - netsa -c 'test -f ~/.config/opencode/opencode.json'")
    machine.succeed("su - netsa -c 'jq -e .mcp.headroom ~/.config/opencode/opencode.json'")
    machine.succeed("su - netsa -c 'jq -e .plugin ~/.config/opencode/opencode.json'")
    machine.succeed("su - netsa -c 'jq -e .mcp.openrouter ~/.config/opencode/opencode.json'")
    machine.succeed("su - netsa -c 'jq -e .mcp.playwright ~/.config/opencode/opencode.json'")

    # 3. Verify the headroom-proxy user unit exists, daemon-reload and start it
    machine.succeed("su - netsa -c 'test -f ~/.config/systemd/user/headroom-proxy.service'")
    machine.succeed(
      "su - netsa -c 'export XDG_RUNTIME_DIR=/run/user/1000"
      " DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus;"
      " systemctl --user daemon-reload'"
    )
    machine.succeed(
      "su - netsa -c 'export XDG_RUNTIME_DIR=/run/user/1000"
      " DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus;"
      " systemctl --user start headroom-proxy.service'"
    )

    # Verify Headroom proxy is running and responds to livez
    machine.wait_until_succeeds("curl -sf http://127.0.0.1:8787/livez", timeout=120)

    # 4. Start and verify opencode-web service
    machine.succeed(
      "su - netsa -c 'export XDG_RUNTIME_DIR=/run/user/1000"
      " DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus;"
      " systemctl --user start opencode-web.service'"
    )

    # Verify OpenCode Web responds over HTTP and returns the OpenCode HTML title
    machine.wait_until_succeeds("curl -sf http://127.0.0.1:4096 | grep -i '<title>OpenCode</title>'", timeout=120)
    machine.succeed("curl -sf -I http://127.0.0.1:4096 | grep -i 'Content-Type: text/html'")

    # 5. Verify MCP end-to-end compression & retrieval probe
    machine.succeed("su - netsa -c 'python3 /etc/vm-mcp-probe.py'")
  '';
}
