{ self, inputs, ... }: {
  flake.nixosModules.common = { config, ... }:
  let
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  in {
    imports = with self.nixosModules; [
      bootstrap
      secrets
      inputs.agenix.nixosModules.default
      app-user
      ssh-root
      inputs.portfolio.nixosModules.default
      inputs.ef-jsl.nixosModules.default
    ];

    services.portfolio = {
      enable = true;
      environmentFiles = [ "/run/agenix/.env" ];
    };

    systemd.services.portfolio = {
      after = [ "postgresql.service" "network-online.target" ];
      requires = [ "postgresql.service" ];
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

    users.users.postgres.extraGroups = [ "app" ];

    systemd.services.postgresql = {
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

    services.caddy = {
      enable = true;
      virtualHosts."jonas.baugerud.no".extraConfig = ''
        reverse_proxy http://localhost:3000
      '';
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}