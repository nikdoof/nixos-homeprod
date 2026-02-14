let
  nikdoof = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHWO2qwHaPaQs46na4Aa6gMkw5QqRHUMGQphtgAcDJOw";
  users = [ nikdoof ];

  svc-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILPHbFY5oPMjAinz46BD8qHTuMgjymS3Vo+57h+iKKWu";
  svc-02 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMTivx90hHNKsMEV1mF/A7XUfkCVxKORubeK4N+uMVk0";
  systems = [
    svc-01
    svc-02
  ];
in
{
  "digitalOceanApiToken.age".publicKeys = users ++ systems;
  "maxmindLicenseKey.age".publicKeys = users ++ systems;

  "borgmaticEncryptionKey.age".publicKeys = users ++ systems;
  "borgmaticSSHKey.age".publicKeys = users ++ systems;

  "swarmMirrorConfig.age".publicKeys = users ++ [ svc-01 ];
  "oauth2ClientSecret.age".publicKeys = users ++ [ svc-01 ];
  "pocketIdEncryptionKey.age".publicKeys = users ++ [ svc-01 ];
  "rusticalClientSecret.age".publicKeys = users ++ [ svc-01 ];
  "goToSocialEnvironment.age".publicKeys = users ++ [ svc-01 ];
  "minifluxEnvironment.age".publicKeys = users ++ [ svc-01 ];
  "linkdingEnvironment.age".publicKeys = users ++ [ svc-01 ];
}
