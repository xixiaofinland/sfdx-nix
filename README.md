# sfdx-nix

A nix flake package for Salesforce `sf` cli, originally forked from [Ryan Faulhaber' repo](https://github.com/rfaulhaber/sfdx-nix)

It downloads source code from Salesforce official cli and compile locally.

It has a weekly [github action](./.github/workflows/update-version.yml) to bump up the cli version automatically (as a PR).

I use it for Salesforce development in my own nix controlled [dotfiles](https://github.com/xixiaofinland/dotfiles-nix/blob/eb829c7045279937232c503e0d108ab09453f9f8/flake.nix#L23)
