let
  nikdoof = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHWO2qwHaPaQs46na4Aa6gMkw5QqRHUMGQphtgAcDJOw";
  users = [ nikdoof ];

  afp-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDoO2RnmZOgSEIfziRh7FJsJPUZe5dLpFXysea5yvEnB";
  gw = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJve5C+8W/Q21qgECyrqnqEvdgah2t72P5A5sUAD8er6";
  hs-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEqU636TZeQGoqkmGUQpkHvs6/AB4cjFgBcmNFJIGWMQ";
  hyp-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKTI5LxG1wD5ee7rhYq9Kv9ArjkgooCODqqCFWh0hvNl";
  mx-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH2WGGEH1jk+Z0Q7zRMXF/ENZtEk8EtfWY3AYBinNtdr";
  ns-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEP/iQjTNADjLloMaSag8AKcLNbNVznEf9l3IYP5a2Y0";
  ns-02 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG+RugXVoPkhVGjW1UzClCSAHlWscbAXxcFvsxqTNM1f";
  svc-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILPHbFY5oPMjAinz46BD8qHTuMgjymS3Vo+57h+iKKWu";
  svc-02 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMTivx90hHNKsMEV1mF/A7XUfkCVxKORubeK4N+uMVk0";
  web-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILBF2Kjr3uDks2Ga1Cm9ItmBuvYthNW0muBccotcIhmZ";
  systems = [
    gw
    hyp-01
    mx-01
    ns-01
    ns-02
    svc-01
    svc-02
    web-01
  ];
in
{
  "digitalOceanApiToken.age".publicKeys = users ++ systems;
  "maxmindLicenseKey.age".publicKeys = users ++ systems;

  "borgmaticEncryptionKey.age".publicKeys = users ++ systems;
  "borgmaticSSHKey.age".publicKeys = users ++ systems;

  "doofnetDhcpUpdateKeyRaw.age".publicKeys = users ++ [ gw ];
  "pppoeCredentials.age".publicKeys = users ++ [ gw ];
  "tailscaleAuthKey.age".publicKeys = users ++ [ gw ];

  "swarmMirrorConfig.age".publicKeys = users ++ [ svc-01 ];
  "oauth2ClientSecret.age".publicKeys = users ++ [ svc-01 ];
  "pocketIdEncryptionKey.age".publicKeys = users ++ [ svc-01 ];
  "rusticalClientSecret.age".publicKeys = users ++ [ svc-01 ];
  "goToSocialEnvironment.age".publicKeys = users ++ [ svc-01 ];
  "minifluxEnvironment.age".publicKeys = users ++ [ svc-01 ];
  "linkdingEnvironment.age".publicKeys = users ++ [ svc-01 ];
  "paperlessClientSecret.age".publicKeys = users ++ [ svc-01 ];
  "gitSecrets.age".publicKeys = users ++ [ svc-01 ];
  "mastodonEnvironment.age".publicKeys = users ++ [ svc-01 ];

  "unpollerPassword.age".publicKeys = users ++ [ svc-02 ];
  "alertManagerTelegramToken.age".publicKeys = users ++ [ svc-02 ];
  "hcloudExporterEnvironment.age".publicKeys = users ++ [ svc-02 ];
  "grafanaOidcClientSecret.age".publicKeys = users ++ [ svc-02 ];
  "aaispLogin.age".publicKeys = users ++ [ svc-02 ];

  "mx01DovecotPasswd.age".publicKeys = users ++ [ mx-01 ];
  "mx01DmarcReportsPassword.age".publicKeys = users ++ [ mx-01 ];

  "doofnetDnsUpdateKey.age".publicKeys = users ++ systems;

  "headscaleClientSecret.age".publicKeys = users ++ [ hs-01 ];

  "dropboxNotifyToken.age".publicKeys = users ++ [ afp-01 ];
}
