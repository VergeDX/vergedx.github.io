#! /usr/bin/env bash

if [ ! -f ./Gemfile.lock ]; then
nix-shell -p bundler -p bundix --run '
  bundler update
	bundler lock
	bundler package --no-install --path vendor
	bundix
	rm -rf vendor
'
fi

nix-shell

