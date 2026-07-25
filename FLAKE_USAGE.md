# Using niversesu/dots-hyprland as a flake

This assumes you've committed `flake.nix`, `nix/default.nix`, and `nix/hm-module.nix`
to the **root** of `github.com/niversesu/dots-hyprland` (replacing/alongside the old
`sdata/dist-nix/home-manager/` WIP — they don't need to conflict, but the root
`flake.nix` is what makes the repo importable as a flake input).

## 0. Before you push: sanity-check it locally

From inside your cloned repo, with Nix + flakes enabled:

```bash
nix flake check
nix build .#illogical-impulse
```

If `nix build` succeeds, `./result/bin/illogical-impulse` should exist. This is the
step I could not run myself (no `nix` in my sandbox), so treat this as the first
thing to do after pushing, before relying on it in a real home-manager config.

### Submodule warning

`dots/.config/quickshell/ii/modules/common/widgets/shapes` is a **git submodule**
(`.gitmodules` points it at `end-4/rounded-polygon-qmljs`). The package derivation
copies real files out of `dots/.config/quickshell/ii`, so if the submodule isn't
checked out, the shell will be missing that directory and fail at runtime.

- Local build (`nix build .#illogical-impulse` from a clone): run
  `git submodule update --init --recursive` first.
- Someone else consuming `github:niversesu/dots-hyprland` as a flake input: plain
  `github:` references do **not** fetch submodules by default. Use:
  ```nix
  dots-hyprland.url = "git+https://github.com/niversesu/dots-hyprland?submodules=1";
  ```
  instead of `github:niversesu/dots-hyprland`, or the submodule content will be
  silently empty in the built package.

## 1. Standalone (no home-manager)

Once it's on GitHub:

```bash
nix run github:niversesu/dots-hyprland#illogical-impulse
```

or build it into your Nix store without running it:

```bash
nix build github:niversesu/dots-hyprland#illogical-impulse
```

## 2. Via home-manager, from a separate flake

This is the normal way to actually use it day-to-day. In some other flake (your
system config, a dotfiles repo, whatever):

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dots-hyprland = {
      url = "git+https://github.com/niversesu/dots-hyprland?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, dots-hyprland, ... }: {
    homeConfigurations.yourusername = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        dots-hyprland.homeManagerModules.default
        {
          home.username = "yourusername";
          home.homeDirectory = "/home/yourusername";
          home.stateVersion = "25.05";

          programs.illogical-impulse = {
            enable = true;
          };
        }
      ];
    };
  };
}
```

Then:

```bash
home-manager switch --flake .#yourusername
```

That gives you the `illogical-impulse` systemd user service (auto-started via
`wayland.systemd.target`, i.e. whenever Hyprland's HM systemd integration fires),
plus the `illogical-impulse` binary on `$PATH`.

## 3. Configuring it

`programs.illogical-impulse` options:

| Option | Default | What it does |
|---|---|---|
| `enable` | `false` | Turn the module on |
| `package` | the flake's own package | Override with your own build if you fork the derivation further |
| `genericLinuxGpu` | `true` | Sets `targets.genericLinux.enable`, needed for GPU access on non-NixOS (see caveats below) |
| `systemd.enable` | `true` | Manage a `systemd --user` service that starts the shell |
| `systemd.target` | `config.wayland.systemd.target` | Which systemd target triggers autostart |
| `systemd.environment` | `[]` | Extra env vars for the service, e.g. `["QT_QPA_PLATFORMTHEME=gtk3"]` |
| `settings` | `{}` | Nix attrset merged into `~/.config/illogical-impulse/config.json` |
| `extraConfig` | `""` | Raw JSON string written first, then `settings` is merged on top |

Example with settings:

```nix
programs.illogical-impulse = {
  enable = true;
  settings = {
    # keys/values here become ~/.config/illogical-impulse/config.json
  };
};
```

If you don't set `settings`/`extraConfig` at all, no `config.json` is written and
the shell falls back to its own defaults (`dots/.config/quickshell/ii/defaults`).

## 4. If you're on NixOS specifically

You don't need `targets.genericLinux.enable` — set `genericLinuxGpu = false;` in
your module config, since that option only exists to work around GPU access on
non-NixOS distros.

## 5. Known gaps (unchanged from upstream's WIP notes)

These aren't fixed by having a proper flake — they're separate, harder problems:

- **PAM / hyprlock**: on non-NixOS, anything using PAM (the screen locker) won't
  work through the Nix-built package. Use your distro's own package for that
  piece specifically.
- **GPU on non-NixOS**: after the first `home-manager switch`, watch the output —
  it'll print a `sudo /nix/store/*-non-nixos-gpu/bin/non-nixos-gpu-setup` command
  you need to run once, manually.
- **The rest of the dotfiles**: this flake only packages `dots/.config/quickshell/ii`
  (the shell itself). `dots/.config/hypr`, `kitty`, `fish`, etc. are still managed
  however you managed them before (e.g. `./setup install-files`) — they are not
  part of `programs.illogical-impulse`.

## 6. Updating the quickshell input

```bash
nix flake lock --update-input quickshell
```

Commit the updated `flake.lock` after. Pin it to a known-good rev in `flake.nix`
(`github:quickshell-mirror/quickshell/<rev>`) if you want reproducible builds
instead of always tracking quickshell's latest commit.
