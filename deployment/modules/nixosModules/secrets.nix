{ ... }: {
  flake.nixosModules.secrets = { ... }: {
    age.secrets.".env" = {
      file = ../../secrets/.env.age;
      mode = "440";
      owner = "app";
      group = "app";
    };
  };
}