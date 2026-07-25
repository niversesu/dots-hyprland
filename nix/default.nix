{
  lib,
  stdenv,
  makeWrapper,
  makeFontsConf,
  quickshell,
  qt6,
  # runtime deps -- mirrors sdata/dist-nix/home-manager/home.nix / sdata/dist-arch/*
  inetutils,
  libnotify,
  dbus,
  xlsclients,
  foot,
  kdePackages,
  lxqt,
  libcava,
  cava,
  wireplumber,
  pipewire,
  libdbusmenu-gtk3,
  playerctl,
  geoclue2,
  brightnessctl,
  ddcutil,
  bc,
  uutils-coreutils-noprefix,
  cliphist,
  cmake,
  curlFull,
  wget,
  ripgrep,
  jq,
  xdg-user-dirs,
  rsync,
  yq-go,
  bibata-cursors,
  adw-gtk3,
  darkly,
  eza,
  fontconfig,
  kitty,
  matugen,
  starship,
  nerd-fonts,
  material-symbols,
  rubik,
  twemoji-color-font,
  hyprsunset,
  wl-clipboard,
  hyprland,
  networkmanager,
  uv,
  gtk4,
  libadwaita,
  libsoup_3,
  libportal-gtk4,
  gobject-introspection,
  hyprshot,
  slurp,
  swappy,
  tesseract,
  wf-recorder,
  upower,
  wtype,
  ydotool,
  fuzzel,
  glib,
  imagemagick,
  hypridle,
  hyprpicker,
  songrec,
  translate-shell,
  wlogout,
  libqalculate,
  hicolor-icon-theme,
  extraRuntimeDeps ? [],
}: let
  qs = quickshell.withModules [
    qt6.qt5compat
    qt6.qtimageformats
    qt6.qtpositioning
  ];

  runtimeDeps =
    [
      inetutils
      libnotify
      dbus
      xlsclients
      foot
      kdePackages.kconfig
      libcava
      cava
      lxqt.pavucontrol-qt
      wireplumber
      pipewire
      libdbusmenu-gtk3
      playerctl
      (geoclue2.override {withDemoAgent = true;})
      brightnessctl
      ddcutil
      bc
      uutils-coreutils-noprefix
      cliphist
      cmake
      curlFull
      wget
      ripgrep
      jq
      xdg-user-dirs
      rsync
      yq-go
      bibata-cursors
      adw-gtk3
      kdePackages.breeze
      kdePackages.breeze-icons
      hicolor-icon-theme
      darkly
      eza
      fontconfig
      kitty
      matugen
      starship
      nerd-fonts.jetbrains-mono
      material-symbols
      rubik
      twemoji-color-font
      hyprsunset
      wl-clipboard
      hyprland
      kdePackages.bluedevil
      networkmanager
      kdePackages.plasma-nm
      kdePackages.dolphin
      kdePackages.systemsettings
      uv
      gtk4
      libadwaita
      libsoup_3
      libportal-gtk4
      gobject-introspection
      hyprshot
      slurp
      swappy
      tesseract
      wf-recorder
      upower
      wtype
      ydotool
      fuzzel
      glib
      imagemagick
      hypridle
      hyprpicker
      songrec
      translate-shell
      wlogout
      libqalculate
      # NOTE: fish is deliberately NOT included here. dots-hyprland's own
      # home.nix excludes it via Nix due to an unresolved auth/PATH problem
      # (install via the distro's package manager instead). caelestia's
      # equivalent list includes fish -- do not copy that back in here.
    ]
    ++ extraRuntimeDeps;

  fontconfig' = makeFontsConf {
    fontDirectories = [material-symbols rubik nerd-fonts.jetbrains-mono];
  };
in
  stdenv.mkDerivation {
    pname = "illogical-impulse";
    version = "unstable";

    # Only the quickshell ("ii") part of the dots is packaged here -- this is
    # the equivalent of what caelestia-dots/shell packages, i.e. the shell
    # itself, not the rest of the dotfiles (hypr/, kitty/, fish/, ...).
    src = lib.fileset.toSource {
      root = ../.;
      fileset = ../dots/.config/quickshell/ii;
    };

    nativeBuildInputs = [makeWrapper qt6.wrapQtAppsHook];
    propagatedBuildInputs = runtimeDeps;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/illogical-impulse
      cp -r dots/.config/quickshell/ii $out/share/illogical-impulse/quickshell

      makeWrapper ${qs}/bin/qs $out/bin/illogical-impulse \
        --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
        --prefix XDG_DATA_DIRS : "${lib.makeSearchPath "share" runtimeDeps}" \
        --set FONTCONFIG_FILE "${fontconfig'}" \
        --add-flags "-p $out/share/illogical-impulse/quickshell"

      runHook postInstall
    '';

    meta = {
      description = "illogical-impulse Quickshell desktop shell from dots-hyprland";
      homepage = "https://github.com/niversesu/dots-hyprland";
      license = lib.licenses.gpl3Only;
      mainProgram = "illogical-impulse";
    };
  }
