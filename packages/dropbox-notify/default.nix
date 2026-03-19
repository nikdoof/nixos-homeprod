{
  lib,
  python3,
}:

python3.pkgs.buildPythonApplication {
  pname = "dropbox-notify";
  version = "0.1.0";
  pyproject = false;

  src = ./.;

  dependencies = with python3.pkgs; [
    inotify-simple
    requests
  ];

  installPhase = ''
    install -Dm755 dropbox_notify.py $out/bin/dropbox-notify
  '';

  meta = {
    description = "Watch a folder with inotify and post to a Mastodon-compatible ActivityPub account on new files";
    license = lib.licenses.mit;
    mainProgram = "dropbox-notify";
    platforms = lib.platforms.linux;
  };
}
