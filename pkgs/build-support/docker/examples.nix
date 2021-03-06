# Examples of using the docker tools to build packages.
#
# This file defines several docker images. In order to use an image,
# build its derivation with `nix-build`, and then load the result with
# `docker load`. For example:
#
#  $ nix-build '<nixpkgs>' -A dockerTools.examples.redis
#  $ docker load < result

{ pkgs, buildImage, pullImage, shadowSetup, buildImageWithNixDb }:

rec {
  # 1. basic example
  bash = buildImage {
    name = "bash";
    contents = pkgs.bashInteractive;
  };

  # 2. service example, layered on another image
  redis = buildImage {
    name = "redis";
    tag = "latest";

    # for example's sake, we can layer redis on top of bash or debian
    fromImage = bash;
    # fromImage = debian;

    contents = pkgs.redis;
    runAsRoot = ''
      mkdir -p /data
    '';

    config = {
      Cmd = [ "/bin/redis-server" ];
      WorkingDir = "/data";
      Volumes = {
        "/data" = {};
      };
    };
  };

  # 3. another service example
  nginx = let
    nginxPort = "80";
    nginxConf = pkgs.writeText "nginx.conf" ''
      user nginx nginx;
      daemon off;
      error_log /dev/stdout info;
      pid /dev/null;
      events {}
      http {
        access_log /dev/stdout;
        server {
          listen ${nginxPort};
          index index.html;
          location / {
            root ${nginxWebRoot};
          }
        }
      }
    '';
    nginxWebRoot = pkgs.writeTextDir "index.html" ''
      <html><body><h1>Hello from NGINX</h1></body></html>
    '';
  in
  buildImage {
    name = "nginx-container";
    contents = pkgs.nginx;

    runAsRoot = ''
      #!${pkgs.stdenv.shell}
      ${shadowSetup}
      groupadd --system nginx
      useradd --system --gid nginx nginx
    '';

    config = {
      Cmd = [ "nginx" "-c" nginxConf ];
      ExposedPorts = {
        "${nginxPort}/tcp" = {};
      };
    };
  };

  # 4. example of pulling an image. could be used as a base for other images
  nixFromDockerHub = pullImage {
    imageName = "nixos/nix";
    imageTag = "1.11";
    # this hash will need change if the tag is updated at docker hub
    sha256 = "0nncn9pn5miygan51w34c2p9qssi96jgsaqv44dxxdprc8pg0g83";
  };

  # 5. example of multiple contents, emacs and vi happily coexisting
  editors = buildImage {
    name = "editors";
    contents = [
      pkgs.coreutils
      pkgs.bash
      pkgs.emacs
      pkgs.vim
      pkgs.nano
    ];
  };

  # 5. nix example to play with the container nix store
  # docker run -it --rm nix nix-store -qR $(nix-build '<nixpkgs>' -A nix)
  nix = buildImageWithNixDb {
    name = "nix";
    contents = [
      # nix-store uses cat program to display results as specified by
      # the image env variable NIX_PAGER.
      pkgs.coreutils
      pkgs.nix
    ];
    config = {
      Env = [ "NIX_PAGER=cat" ];
    };
  };
}
