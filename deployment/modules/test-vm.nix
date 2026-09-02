{ inputs, self, ... }: {
  flake.nixosConfigurations.test-vm = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.app-user
      inputs.portfolio.nixosModules.default
      ({ config, ... }:
      let
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
      in {
        services.portfolio = {
          enable = true;
          environmentFiles = [ "/run/agenix/.env" ];
        };

        systemd.services.portfolio = {
          after = [ "load-env.service" "postgresql.service" "network-online.target" ];
          requires = [ "load-env.service" "postgresql.service" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            User = "app";
            Group = "app";
          };
        };

        services.postgresql ={
          enable = true;
          package = pkgs.postgresql_18;
          ensureDatabases = [
            "db"
          ];
        };

        systemd.network.wait-online.enable = true;

        systemd.services.postgresql = {
          after = [ "load-env.service" ];
          requires = [ "load-env.service" ];
          postStart = ''
            set -a
            source /run/agenix/.env
            set +a
            ${config.services.postgresql.package}/bin/psql -d postgres <<EOF
            DO \$\$
            BEGIN
              IF EXISTS (SELECT FROM pg_roles WHERE rolname = '$POSTGRES_USER') THEN
                ALTER USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';
              ELSE
                CREATE ROLE $POSTGRES_USER WITH LOGIN PASSWORD '$POSTGRES_PASSWORD';
              END IF;
            END
            \$\$;
          EOF
          '';
        };

        system.stateVersion = "25.11";
        users.users.root.password = "root";
        services.getty.autologinUser = "root";

        virtualisation.vmVariant = {
          virtualisation.graphics = false;
          virtualisation.sharedDirectories = {
            env-dir = {
              source = "$ENV_DIR";   # set by the wrapper script
              target = "/mnt/env-host";
            };
          };
          virtualisation.forwardPorts = [
            { from = "host"; host.port = 443; guest.port = 443; }
            { from = "host"; host.port = 80; guest.port = 80; }
          ];
        };

        users.users.postgres.extraGroups = [ "app" ];

        systemd.services.load-env = {
          description = "Load .env from host shared directory";
          wantedBy = [ "multi-user.target" ];
          before = [ "portfolio.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            mkdir -p /run/agenix
            if [ -f /mnt/env-host/.env ]; then
              cp /mnt/env-host/.env /run/agenix/.env
              chown app:app /run/agenix/.env
              chmod 640 /run/agenix/.env
              echo "Loaded .env from host"
            else
              echo "WARNING: No .env found at /mnt/env-host/.env" >&2
            fi
          '';
        };
        
        networking.firewall.allowedTCPPorts = [ 443 80 ];
        services.caddy ={
          enable = true; # Should reverse proxy to localhost 3000
          virtualHosts."localhost".extraConfig = ''
            tls internal
            reverse_proxy http://localhost:3000
          '';
        };
      })
    ];
  };
}