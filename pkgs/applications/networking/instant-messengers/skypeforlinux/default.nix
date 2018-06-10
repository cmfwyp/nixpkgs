{ stdenv, fetchurl, dpkg, makeWrapper
, alsaLib, atk, cairo, cups, curl, dbus, expat, fontconfig, freetype, gdk_pixbuf, glib, glibc, gnome3
, gtk2, libnotify, libpulseaudio, libsecret, libv4l, nspr, nss, pango, systemd, xorg }:

let

  # Please keep the version x.y.0.z and do not update to x.y.76.z because the
  # source of the latter disappears much faster.
  version = "8.18.0.6";

  rpath = stdenv.lib.makeLibraryPath [
    alsaLib
    atk
    cairo
    cups
    curl
    dbus
    expat
    fontconfig
    freetype
    glib
    glibc
    libsecret

    gnome3.gconf
    gdk_pixbuf
    gtk2


    gnome3.gnome-keyring

    libnotify
    libpulseaudio
    nspr
    nss
    pango
    stdenv.cc.cc
    systemd
    libv4l

    xorg.libxkbfile
    xorg.libX11
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libXScrnSaver
    xorg.libxcb
  ] + ":${stdenv.cc.cc.lib}/lib64";

  src =
    if stdenv.system == "x86_64-linux" then
      fetchurl {
        url = "https://repo.skype.com/deb/pool/main/s/skypeforlinux/skypeforlinux_${version}_amd64.deb";
        sha256 = "193icz1s385d25qzm5vx58h66m4hfwwmkavn0p3w6631gj617hig";
      }
    else
      throw "Skype for linux is not supported on ${stdenv.system}";

in stdenv.mkDerivation {
  name = "skypeforlinux-${version}";

  system = "x86_64-linux";

  inherit src;

  buildInputs = [ dpkg makeWrapper ];

  unpackPhase = "true";
  installPhase = ''
    mkdir -p $out
    dpkg -x $src $out
    cp -av $out/usr/* $out
    rm -rf $out/opt $out/usr
    rm $out/bin/skypeforlinux

    # Otherwise it looks "suspicious"
    chmod -R g-w $out
  '';

  postFixup = ''
    for file in $(find $out -type f \( -perm /0111 -o -name \*.so\* -or -name \*.node\* \) ); do
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
      patchelf --set-rpath ${rpath}:$out/share/skypeforlinux $file || true
    done

    ln -s "$out/share/skypeforlinux/skypeforlinux" "$out/bin/skypeforlinux"

    # Fix the desktop link
    substituteInPlace $out/share/applications/skypeforlinux.desktop \
      --replace /usr/bin/ $out/bin/ \
      --replace /usr/share/ $out/share/
  '';

  meta = with stdenv.lib; {
    description = "Linux client for skype";
    homepage = https://www.skype.com;
    license = licenses.unfree;
    maintainers = with stdenv.lib.maintainers; [ panaeon jraygauthier ];
    platforms = [ "x86_64-linux" ];
  };
}