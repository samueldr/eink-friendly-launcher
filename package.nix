{ stdenv

, meson
, ninja

, pkg-config
, vala

, glib
, gtk4
, libgee
}:

stdenv.mkDerivation {
  pname = "eink-friendly-launcher";
  version = "2023-04-13";

  src = builtins.fetchGit ./.;

  buildInputs = [
    glib
    gtk4
    libgee
  ];

  nativeBuildInputs = [
    meson
    ninja

    pkg-config
    vala
  ];
}
