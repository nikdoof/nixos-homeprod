let
  nikdoof = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHWO2qwHaPaQs46na4Aa6gMkw5QqRHUMGQphtgAcDJOw";
  users = [ nikdoof ];

  svc-01 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILPHbFY5oPMjAinz46BD8qHTuMgjymS3Vo+57h+iKKWu";
  systems = [ svc-01 ];
in
{
  "digitalOceanApiToken.age".publicKeys = users ++ systems;

  "borgmaticEncryptionKey.age".publicKeys = users ++ systems;
  "borgmaticSSHKey.age".publicKeys = users ++ systems;

  "swarmMirrorConfig.age".publicKeys = users ++ [ svc-01 ];
}
