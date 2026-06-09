{ inputs, self, ... }: {
  flake.nixosConfigurations.test-vm = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      inputs.portfolio.nixosModules.default
      ({ ... }: {
        services.portfolio = {
          enable = true;
          environmentFiles = [ "/run/secrets/.env" ];
        };

        systemd.services.portfolio = {
          after = [ "load-env.service" ];
          requires = [ "load-env.service" ];
        };

        system.stateVersion = "25.11";
        users.users.root.password = "root";
        services.getty.autologinUser = "root";

        virtualisation.vmVariant = {
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

        systemd.services.load-env = {
          description = "Load .env from host shared directory";
          wantedBy = [ "multi-user.target" ];
          before = [ "portfolio.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            mkdir -p /run/secrets
            if [ -f /mnt/env-host/.env ]; then
              cp /mnt/env-host/.env /run/secrets/.env
              chmod 600 /run/secrets/.env
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