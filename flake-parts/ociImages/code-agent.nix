_: {
  # ------ Per-System ------ #
  # General-purpose coding sandbox image for OpenShell (VM driver): a
  # lean, hand-picked toolset + nix (runtime package adds via
  # substitution) + first-class VSCodium Remote-SSH support. This is the
  # single place OpenShell sandbox images come from — devenv stays
  # human-only.
  #
  # Built with nix2container, NOT dockerTools: the VM driver's image-prep
  # (umoci-v3) reproducibly corrupts the ext4 it produces from the
  # dockerTools stream of a large image ("Block bitmap checksum does not
  # match"), while nix2container images (same layer counts, same sizes)
  # provision fine. Tiny dockerTools images pass, so the trigger is
  # size/layer-count dependent; nix2container is the proven path on this
  # driver.
  #
  # Delivery to the VM driver (openshell-driver-vm): the driver first
  # checks the host container engine's local image store, so
  # `nix run .#load-code-agent-image` (skopeo copy into docker-daemon:)
  # is enough; OCI registry pull is the fallback.
  #
  # Remote-SSH contract (learned the hard way): the in-VM sshd runs
  # extension commands with a store-only PATH, so the install-script
  # toolchain lives in /usr/local/bin (+ /etc/profile for login shells)
  # on top of /bin from the base toolset; the vscodium-reh tarball's
  # bundled node is a foreign glibc binary — it gets patchelf'd to the
  # image glibc (pre-baked server below), and the general FHS fallback
  # (/lib64 loader, classic lib dirs, baked ld.so.cache) covers any
  # other downloaded ELF.
  perSystem = {
    pkgs,
    inputs',
    self',
    customLib,
    ...
  }: let
    inherit (pkgs) lib;
    inherit (customLib) relativeToRoot;
    n2c = inputs'.nix2container.packages.nix2container;

    # VSCodium release whose vscodium-reh server matches the fleet's
    # codium 1.126.0 (DISTRO_COMMIT from `Help > About`). Bump both when
    # nixpkgs' vscodium moves; on mismatch the install script falls back
    # to downloading (github.com + *.githubusercontent.com must stay
    # admitted in openshell/policies/code-agent.yaml).
    vscodiumVersion = "1.126.04524";
    vscodiumCommit = "4c0b0c6cc561d2d3636d1ec250935431876ce4dc";

    # vscodium-reh server payload with the bundled node patchelf'd to
    # the image toolchain: nix store rpath/interpreter, so it runs with
    # no env, no ld.so.cache dependency, and no FHS assumptions.
    vscodium-server = pkgs.stdenv.mkDerivation {
      pname = "vscodium-reh";
      version = vscodiumVersion;
      src = pkgs.fetchurl {
        url = "https://github.com/VSCodium/vscodium/releases/download/${vscodiumVersion}/vscodium-reh-linux-x64-${vscodiumVersion}.tar.gz";
        hash = "sha256-NC+skexxc6/7jdALQ5uGiz7mziKdx9GLuUx83W2YWoA=";
      };
      nativeBuildInputs = [pkgs.patchelf];
      dontUnpack = true;
      dontStrip = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out
        tar -xzf $src -C $out --strip-components=1
        patchelf \
          --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
          --set-rpath ${lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib pkgs.glibc]} \
          $out/node
        # The upstream tarball ships scripts with the CI's nix store
        # bash in the shebang — an accident of matching nixpkgs pins,
        # not a contract. Point them at the image bash.
        sed -i '1s|^#!.*|#!${pkgs.bashInteractive}/bin/sh|' $out/bin/codium-server
        runHook postInstall
      '';
    };

    # /bin + /usr/bin toolset (the sshd default PATH covers /bin) plus
    # merged /etc contributions (ssl certs, ssh client config, nix
    # profile snippets, /usr/bin/env).
    baseTools = pkgs.buildEnv {
      name = "code-agent-base";
      paths = with pkgs; [
        bashInteractive
        coreutils
        gnused
        gnugrep
        gawk
        findutils
        gnutar
        gzip
        xz
        procps
        util-linux
        git
        gh
        curl
        cacert
        jq
        ripgrep
        openssh
        tmux
        less
        nix
        # Nix language server + the repo's lint trio: agent-edited
        # .nix files can be vetted in-sandbox (runtime `nix profile
        # install` adds work too, but TCG builds crawl — bake them).
        nixd
        alejandra
        statix
        deadnix
        # AI coding agents (all from the llm-agents flake input, see
        # overlays/default.nix): pi runs on bun, kimi-code and
        # claude-code are bundled node/bun apps — closures carry their
        # runtimes.
        pi-coding-agent
        kimi-code
        claude-code
        dockerTools.usrBinEnv
      ];
      pathsToLink = ["/bin" "/usr/bin" "/etc"];
    };

    # FHS rootfs additions merged at the image /:
    #  - /usr/local/bin: install-script + server-side toolchain, in case
    #    the sshd PATH lacks /bin in some invocation path.
    #  - /etc/{os-release,profile,passwd,group,shadow,ld.so.conf,
    #    ld.so.cache}: truthful os-release for the install script, PATH
    #    for login shells, identity for nix (getpwuid home lookup) and
    #    the vscodium server's shells, and a pregenerated loader cache —
    #    nixpkgs glibc's compiled-in search path covers no FHS dirs and
    #    /etc is read-only under the OpenShell policy, so foreign ELFs
    #    (anything not patchelf'd like the bundled node above) resolve
    #    via the cache.
    #  - /lib64/ld-linux-x86-64.so.2 + glibc/gcc libs COPIED into the
    #    classic multiarch dirs (real files, not symlinks: the cache is
    #    generated in a chroot where /nix/store is unreachable, and
    #    dangling symlinks would produce no entries).
    rootfs = pkgs.runCommand "code-agent-rootfs" {} ''
      mkdir -p $out/usr/local/bin $out/etc \
        $out/lib64 $out/usr/lib64 $out/lib $out/usr/lib \
        $out/lib/x86_64-linux-gnu $out/usr/lib/x86_64-linux-gnu

      # sshd-default-PATH toolchain.
      ln -s ${pkgs.bashInteractive}/bin/bash        $out/usr/local/bin/bash
      ln -s ${pkgs.coreutils}/bin/uname             $out/usr/local/bin/uname
      ln -s ${pkgs.gnused}/bin/sed                  $out/usr/local/bin/sed
      ln -s ${pkgs.gnugrep}/bin/grep                $out/usr/local/bin/grep
      ln -s ${pkgs.gnutar}/bin/tar                  $out/usr/local/bin/tar
      ln -s ${pkgs.gzip}/bin/gzip                   $out/usr/local/bin/gzip
      ln -s ${pkgs.gzip}/bin/gunzip                 $out/usr/local/bin/gunzip
      ln -s ${pkgs.curl}/bin/curl                   $out/usr/local/bin/curl
      ln -s ${pkgs.procps}/bin/ps                   $out/usr/local/bin/ps
      ln -s ${pkgs.util-linux}/bin/flock            $out/usr/local/bin/flock
      ln -s ${pkgs.git}/bin/git                     $out/usr/local/bin/git
      ln -s ${pkgs.gh}/bin/gh                       $out/usr/local/bin/gh
      ln -s ${pkgs.jq}/bin/jq                       $out/usr/local/bin/jq
      ln -s ${pkgs.ripgrep}/bin/rg                  $out/usr/local/bin/rg
      ln -s ${pkgs.tmux}/bin/tmux                   $out/usr/local/bin/tmux
      ln -s ${pkgs.less}/bin/less                   $out/usr/local/bin/less
      ln -s ${pkgs.openssh}/bin/ssh                 $out/usr/local/bin/ssh
      ln -s ${pkgs.nix}/bin/nix                     $out/usr/local/bin/nix
      ln -s ${pkgs.pi-coding-agent}/bin/pi          $out/usr/local/bin/pi
      ln -s ${pkgs.kimi-code}/bin/kimi              $out/usr/local/bin/kimi
      ln -s ${pkgs.claude-code}/bin/claude          $out/usr/local/bin/claude
      ln -s ${pkgs.nixd}/bin/nixd                   $out/usr/local/bin/nixd
      ln -s ${pkgs.alejandra}/bin/alejandra         $out/usr/local/bin/alejandra
      ln -s ${pkgs.statix}/bin/statix               $out/usr/local/bin/statix
      ln -s ${pkgs.deadnix}/bin/deadnix             $out/usr/local/bin/deadnix

      # Login shells (interactive SSH + VSCodium terminal) read
      # /etc/profile: put the layer on PATH there too.
      cat > $out/etc/profile <<'EOF'
      export PATH="/usr/local/bin:$PATH"
      EOF

      printf '%s\n' 'NAME="code-agent"' 'ID="code-agent"' > $out/etc/os-release

      # Git defaults: the org bot identity (andrewthomaslee-agent, per
      # the external-systems org — per-repo config can still override)
      # and a credential helper scoped to github.com that feeds git the
      # provider-injected $GITHUB_TOKEN — without it git prompts for
      # credentials on every https push. Scoped by URL on purpose: only
      # github.com receives the (opaque) handle; the supervisor
      # substitutes the real token at egress.
      cat > $out/etc/gitconfig <<'EOF'
      [user]
      	name = andrewthomaslee-agent
      	email = andrewthomaslee-agent@users.noreply.github.com
      [credential "https://github.com"]
      	helper = "!f() { echo username=x-access-token; echo password=$GITHUB_TOKEN; }; f"
      EOF

      # Minimal identity database: nix resolves the user's home via
      # getpwuid, and the vscodium server spawns shells for uid 1000.
      cat > $out/etc/passwd <<EOF
      root:x:0:0:System administrator:/root:${pkgs.bashInteractive}/bin/bash
      agent:x:1000:1000:Agent:/home/agent:${pkgs.bashInteractive}/bin/bash
      EOF
      cat > $out/etc/group <<EOF
      root:x:0:
      agent:x:1000:
      EOF
      echo 'root:!x:::::::' > $out/etc/shadow
      echo 'agent:!x:::::::' >> $out/etc/shadow

      # Dynamic loader + libs for foreign glibc binaries. The ~60MB of
      # copies is deliberate: see the rootfs comment block above.
      cp -L ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 $out/lib64/ld-linux-x86-64.so.2
      for lib in ${pkgs.glibc}/lib/*.so* ${pkgs.stdenv.cc.cc.lib}/lib/*.so*; do
        base=$(basename "$lib")
        cp -L "$lib" "$out/lib/$base"
        cp -L "$lib" "$out/usr/lib/$base"
        cp -L "$lib" "$out/usr/lib64/$base"
        cp -L "$lib" "$out/lib/x86_64-linux-gnu/$base"
        cp -L "$lib" "$out/usr/lib/x86_64-linux-gnu/$base"
      done

      cat > $out/etc/ld.so.conf <<'EOF'
      /lib
      /usr/lib
      /lib64
      /usr/lib64
      /lib/x86_64-linux-gnu
      /usr/lib/x86_64-linux-gnu
      EOF
      # -r chroots into $out so cache entries are image-absolute; -C is
      # required because nixpkgs glibc's default cache path points at
      # its own (read-only) store etc/.
      ${pkgs.glibc.bin}/sbin/ldconfig -r $out -f /etc/ld.so.conf \
        -C /etc/ld.so.cache
    '';

    # Home, workdir, and the pre-baked per-agent wiring. Owned
    # 1000:1000 via perms below (OpenShell runs USER-less images as
    # UID/GID 1000; the image declares that user explicitly).
    agentDirs = pkgs.runCommand "code-agent-dirs" {} ''
      mkdir -p $out/home/agent $out/sandbox/.vscodium-server/bin
      # Pre-baked server at the path the jeanp413 open-remote-ssh
      # install script probes ($HOME/.vscodium-server with HOME=/sandbox
      # under the supervisor): script present means "already installed",
      # so connect is instant and offline.
      ln -s ${vscodium-server} $out/sandbox/.vscodium-server/bin/${vscodiumCommit}

      # pi's kimi-for-coding wiring: models.json overrides the built-in
      # kimi-coding provider to read its key from $KIMI_API_KEY (env
      # interpolation, no key in the image). Baked at both $HOME roots:
      # the supervisor points HOME at /sandbox, plain docker runs at
      # /home/agent.
      mkdir -p $out/sandbox/.pi/agent $out/home/agent/.pi/agent
      cp ${pi-models} $out/sandbox/.pi/agent/models.json
      cp ${pi-models} $out/home/agent/.pi/agent/models.json
      # pi skills: explicit resource path at the canonical baked
      # location (the ~/.agents/skills symlink below is the same tree
      # via the Agent Skills standard location, belt and braces).
      cp ${pi-settings} $out/sandbox/.pi/agent/settings.json
      cp ${pi-settings} $out/home/agent/.pi/agent/settings.json

      # kimi-code: config.toml pre-wires the Kimi for Coding
      # subscription (no /login — the OAuth hosts are deliberately
      # unreachable under the sandbox policy); skills dir at the
      # location kimi scans ($KIMI_CODE_HOME/skills).
      mkdir -p $out/sandbox/.kimi-code $out/home/agent/.kimi-code
      cp ${kimi-config} $out/sandbox/.kimi-code/config.toml
      cp ${kimi-config} $out/home/agent/.kimi-code/config.toml
      ln -s /opt/skills $out/sandbox/.kimi-code/skills
      ln -s /opt/skills $out/home/agent/.kimi-code/skills

      # claude: personal skills dir + first-run onboarding skipped
      # (settings.json and the legacy ~/.claude.json both carry
      # hasCompletedOnboarding — claude merges either).
      mkdir -p $out/sandbox/.claude $out/home/agent/.claude
      cp ${claude-settings} $out/sandbox/.claude/settings.json
      cp ${claude-settings} $out/home/agent/.claude/settings.json
      cp ${claude-settings} $out/sandbox/.claude.json
      cp ${claude-settings} $out/home/agent/.claude.json
      ln -s /opt/skills $out/sandbox/.claude/skills
      ln -s /opt/skills $out/home/agent/.claude/skills

      # Agent Skills standard location, scanned by pi and claude-code
      # (and walked as a project-root skill dir from any /sandbox cwd).
      mkdir -p $out/sandbox/.agents $out/home/agent/.agents
      ln -s /opt/skills $out/sandbox/.agents/skills
      ln -s /opt/skills $out/home/agent/.agents/skills
    '';

    # Repo agent material baked read-only at /opt: the home repo's
    # skills/ tree (wired into pi/kimi/claude in agentDirs above) and
    # references/ tree (deep "how it works" docs these CLIs don't
    # auto-discover — agents reach them through the skills that point
    # there, or on an explicit read).
    agentMaterial = pkgs.runCommand "code-agent-material" {} ''
      mkdir -p $out/opt
      cp -r ${relativeToRoot "skills"} $out/opt/skills
      cp -r ${relativeToRoot "references"} $out/opt/references
    '';

    # pi user settings: the baked skills tree as an explicit resource
    # path (absolute paths are supported; resolves regardless of HOME).
    pi-settings = pkgs.writeText "pi-settings.json" ''
      {
        "skills": ["/opt/skills"]
      }
    '';

    # kimi-code pre-wired for the Kimi for Coding subscription — the
    # same api.kimi.com/coding product pi's built-in kimi-coding provider
    # uses, over the wire Moonshot's own CLI speaks to it (the kimi
    # wire's managed default base URL is exactly .../coding/v1, Bearer
    # auth via apiKeyEnv — the OpenAI-style chat-completions surface,
    # not the Anthropic /messages one). The key is the provider-injected
    # $KIMI_API_KEY, so no /login and no auth.kimi.com egress. If
    # Moonshot ever moves the wire, the Anthropic-protocol variant is
    # type = "anthropic" + baseUrl = "https://api.kimi.com/coding".
    kimi-config = pkgs.writeText "kimi-config.toml" ''
      defaultProvider = "kimi-for-coding"
      defaultModel = "kimi-for-coding"

      [providers.kimi-for-coding]
      type = "kimi"
      baseUrl = "https://api.kimi.com/coding/v1"
      apiKeyEnv = "KIMI_API_KEY"

      [models.kimi-for-coding]
      provider = "kimi-for-coding"
      model = "kimi-for-coding"
      maxContextSize = 1048576
      maxOutputSize = 32768
    '';

    # Claude Code: skip the first-run onboarding prompts (theme/terms).
    # Auth itself is the attached claude-code provider's job
    # ($ANTHROPIC_AUTH_TOKEN); the platform.claude.com preflight is
    # admitted by the policy, and the updater/telemetry env in the
    # image config keeps non-API traffic off the DENIED log.
    claude-settings = pkgs.writeText "claude-settings.json" ''
      {
        "hasCompletedOnboarding": true,
        "theme": "dark"
      }
    '';

    # pi's built-in kimi-coding provider, pointed at the key the
    # kimi-for-coding OpenShell provider injects as $KIMI_API_KEY.
    pi-models = pkgs.writeText "pi-models.json" ''
      {
        "providers": {
          "kimi-coding": {
            "apiKey": "$KIMI_API_KEY"
          }
        }
      }
    '';

    tmpDir = pkgs.runCommand "code-agent-tmp" {} "mkdir -p $out/tmp";

    # Multiline NIX_CONFIG: flakes on; the microVM is the isolation
    # boundary and the OpenShell supervisor's seccomp stack blocks nix's
    # builder-child filter ("unable to load seccomp BPF program:
    # Operation not permitted"), so builders skip their own filter.
    # FlakeHub substituters mirror the host caches (public keys only),
    # plus clan-core's niks3 cache (cache.geninf.io; objects may be
    # signed under either cache.geninf.io-1 or cache.clan.lol-1, so both
    # keys are trusted — keys verbatim from the cache's own usage page).
    nixConfig = lib.concatStringsSep "\n" [
      "experimental-features = nix-command flakes"
      "sandbox = false"
      "filter-syscalls = false"
      "extra-substituters = https://cache.flakehub.com/ https://edge.cache.flakehub.com/ https://cache.geninf.io/"
      "extra-trusted-public-keys = cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio= cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU= cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU= cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8= cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ= cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o= cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y= cache.geninf.io-1:uhEViaczNKSoerYM+w7uqXUzlAhnbEBKsFzgg9n3cvI= cache.clan.lol-1:3KztgSAB5R1M+Dz7vzkBGzXdodizbgLXGXKXlcQLA28="
    ];
  in {
    packages.code-agent-image = n2c.buildImage {
      name = "code-agent";
      tag = "latest";

      copyToRoot = [baseTools rootfs agentDirs agentMaterial tmpDir];

      # Register the image store paths in the nix db at build time so
      # `nix` works in-sandbox without a db init.
      initializeNixDatabase = true;
      nixUid = 1000;
      nixGid = 1000;

      maxLayers = 128;

      perms = [
        {
          path = agentDirs;
          regex = ".*";
          # nix store defaults are 0555; without an explicit mode the
          # workdir would be read-only for the runtime user.
          mode = "0755";
          uid = 1000;
          gid = 1000;
          uname = "agent";
          gname = "agent";
        }
        {
          path = tmpDir;
          regex = "/tmp";
          mode = "1777";
          uid = 0;
          gid = 0;
          uname = "root";
          gname = "root";
        }
      ];

      config = {
        User = "agent";
        WorkingDir = "/sandbox";
        Env = [
          "HOME=/home/agent"
          "NIX_CONFIG=${nixConfig}"
          "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
          # pi defaults to the kimi-for-coding subscription endpoint; the
          # key itself is injected by the attached kimi-for-coding
          # provider (models.json above reads it from $KIMI_API_KEY).
          "PI_PROVIDER=kimi-coding"
          "PI_MODEL=kimi-for-coding"
          # kimi-code: no models.dev catalog fetch on start (no catalog
          # egress under the sandbox policy — the provider/model is
          # baked in config.toml) and no telemetry.
          "KIMI_CODE_MODEL_CATALOG_REFRESH_ON_START=false"
          "KIMI_DISABLE_TELEMETRY=1"
          # claude-code: updater/telemetry/error-reporting/survey traffic
          # all targets hosts the policy does not admit; disabling keeps
          # the DENIED log to real API traffic. (The startup connectivity
          # preflight is NOT telemetry — platform.claude.com is admitted
          # in openshell/policies/code-agent.yaml for it and for
          # `claude auth login` token polling.)
          "DISABLE_AUTOUPDATER=1"
          "DISABLE_TELEMETRY=1"
          "DISABLE_ERROR_REPORTING=1"
          "DISABLE_BUG_COMMAND=1"
          "DISABLE_GROWTHBOOK=1"
          "DISABLE_FEEDBACK_SURVEY=1"
        ];
        Cmd = ["${pkgs.bashInteractive}/bin/bash" "-l"];
      };
    };

    # The nix2container image is an image-spec JSON, not a loadable
    # tarball: copy it into the host docker store (where the VM driver
    # resolves images first) with skopeo. Registry pull is the fallback.
    apps.load-code-agent-image = {
      type = "app";
      program = toString (pkgs.writeShellScript "load-code-agent-image" ''
        set -euo pipefail
        exec ${inputs'.nix2container.packages.skopeo-nix2container}/bin/skopeo --insecure-policy \
          copy "nix:${self'.packages.code-agent-image}" docker-daemon:code-agent:latest
      '');
    };
  };
}
