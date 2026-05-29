{ self, inputs, ... }: {
  flake.nixosModules.common = { config, ... }: {
    imports = with self.nixosModules; [
      bootstrap
      secrets
      inputs.agenix.nixosModules.default
      app-user
      ssh-root
      inputs.portfolio.nixosModules.default
    ];

    services.portfolio = {
      enable = true;
      environmentFiles = [ "/run/secrets/.env" ];
    };

    services.caddy ={
      enable = true;
      virtualHosts."jonas.baugerud.no".extraConfig = ''
        reverse_proxy http://localhost:3000
      '';
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}