{ ... }:
hostName:
let
  hashedHostOctet =
    pos:
    let
      sha1Hash = builtins.hashString "sha1" hostName;
      hexValue = builtins.substring (2 * pos) 2 sha1Hash;
    in
    hexValue;
in
"02:00:00:${hashedHostOctet 1}:${hashedHostOctet 2}:${hashedHostOctet 3}"
