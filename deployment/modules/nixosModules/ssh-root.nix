{ ... }: {
  flake.nixosModules.ssh-root = { ... }: {
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
    };

    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIhW18wA49y3+skZhUAWMG+HY0MuhoSlvSUdJaPpIuCz" # Bootstrap key
    ];
  };
}