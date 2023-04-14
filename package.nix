{ stdenv

, meson
, ninja

, pkg-config
, vala

, glib
, gtk4
, libgee

, eink-friendly-launcher-src ? ./.
}:

stdenv.mkDerivation {
  pname = "eink-friendly-launcher";
  version = "2023-04-13";

  src = eink-friendly-launcher-src;

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
