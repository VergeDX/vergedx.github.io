# https://nathan.gs/2019/04/19/using-jekyll-and-nix-to-blog/
with import <nixpkgs> { };

let jekyll_env = bundlerEnv rec {
  name = "jekyll_env";
  inherit ruby;

  gemfile = ./Gemfile;
  lockfile = ./Gemfile.lock;
  gemset = ./gemset.nix;
};
in
stdenv.mkDerivation rec {
  name = "vergedx.github.io";
  buildInputs = [ jekyll_env bundler ruby ];

  # https://github.com/kaeyleo/jekyll-theme-H2O#:~:text=jekyll%20build
  shellHook = "exec ${jekyll_env}/bin/jekyll build -s ../";
}
