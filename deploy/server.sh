#! /usr/bin/env bash

if [ ! -f ./Gemfile.lock ] || [ ! -f ./gemset.nix ]; then
nix-shell -p bundler -p bundix --run '
  bundler update
	bundler lock
	bundler package --no-install --path vendor
	bundix
	rm -rf vendor
'
fi

nix-shell

