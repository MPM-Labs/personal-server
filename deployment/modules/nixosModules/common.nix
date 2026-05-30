{ self, inputs, ... }: {
  flake.nixosModules.common = { config, ... }: {
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

    services."drinks-app" = {
      enable = true;
      environmentFiles = [ "/run/agenix/.env" ];
    };

    services.caddy ={
      enable = true;
      virtualHosts."jonas.baugerud.no".extraConfig = ''
        reverse_proxy http://localhost:3000
      '';
      virtualHosts."jostilimleverer.club".extraConfig = ''
        reverse_proxy http://localhost:5000
      '';
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}