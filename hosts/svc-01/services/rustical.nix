{ config, pkgs, ... }:

let
  rusticalConfig = pkgs.writeText "config.toml" ''
    [oidc]
    name = "Doofnet"
    issuer = "https://id.doofnet.uk"
    client_id = "908ba885-2fbd-4bfc-b7d3-80a500e18caa"
    claim_userid = "preferred_username"
    scopes = ["openid", "email", "profile", "groups"]
    require_group = "home"
    allow_sign_up = true

    [oidc.assign_memberships]
    home = ["home"]

    [frontend]
    allow_password_login = false

    [tracing]
    opentelemetry = true

    [dav_push]
    enabled = true
  '';
in
{
  age.secrets = {
    rusticalClientSecret = {
      file = ../../../secrets/rusticalClientSecret.age;
    };
  };

  virtualisation.oci-containers.containers.rustical = {
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.rustical.rule" = "Host(`cal.doofnet.uk`)";
      "traefik.http.services.rustical.loadbalancer.server.port" = "4000";
      "traefik.http.routers.rustical.entrypoints" = "websecure,extwebsecure";
    };
    image = "ghcr.io/lennart-k/rustical:0.13.1";
    environmentFiles = [ config.age.secrets.rusticalClientSecret.path ];
    volumes = [
      "${rusticalConfig}:/etc/rustical/config.toml:ro"
      "/srv/data/rustical/data:/var/lib/rustical:U"
    ];
  };

  services.borgmatic.settings.source_directories = [ "/srv/data/rustical/data" ];
}
