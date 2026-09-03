Name:           ktoot
Version:        0.3.0
Release:        1%{?dist}
URL:            https://github.com/Agundur-KDE/KToot
Summary:        Mastodon notification widget for KDE Plasma (pure QML plasmoid)
License:        GPL-3.0-or-later
Source0: _service

BuildRequires:  cmake
BuildRequires:  extra-cmake-modules
BuildRequires:  qt6-base-devel
BuildRequires:  qt6-declarative-devel
BuildRequires:  kf6-kconfig-devel
BuildRequires:  kf6-ki18n-devel
BuildRequires:  kf6-kcmutils-devel
BuildRequires:  kf6-knotifications-devel
BuildRequires:  kf6-kiconthemes-devel

Requires:       plasma6-workspace

%description
KToot is a KDE Plasma 6 applet (plasmoid), pure QML, that shows Mastodon
notifications and lets you post toots from your panel/desktop.

%prep

rm -rf ./*

shopt -s nullglob
picked=""
for d in %{_sourcedir}/ktoot-* %{_sourcedir}/KToot-* %{_sourcedir}/ktoot ; do
  if [ -d "$d" ] && [ -f "$d/CMakeLists.txt" ]; then
    picked="$d"
    break
  fi
done

if [ -n "$picked" ]; then
  cp -a "$picked"/. .
else
  for f in %{_sourcedir}/* ; do
    base="$(basename "$f")"
    case "$base" in
      *.spec|*.dsc|*.changes|*.obsinfo|_service|service_attic|screenshot|*.patch)
        continue ;;
    esac
    cp -a "$f" .
  done
fi

%build
%cmake \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DBUILD_TESTING=OFF \
  -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
  -DKDE_INSTALL_QMLDIR=%{_qt6_qmldir} \
  -DKDE_INSTALL_PLUGINDIR=%{_qt6_plugindir}
%cmake_build

%install
%cmake_install

%files
%license LICENSE
%doc README.md
%{_datadir}/plasma/plasmoids/de.agundur.ktoot/
%{_datadir}/knotifications6/ktoot.notifyrc
%{_datadir}/icons/hicolor/*/apps/ktoot.png
%{_datadir}/locale/*/LC_MESSAGES/plasma_applet_*.agundur.ktoot.mo

%changelog
* Thu Sep 03 2026 Alec <info@agundur.de> - 0.3.0-1
- First public release: Mastodon notification widget for KDE Plasma 6.
- KWallet access moved to pure QML/D-Bus (org.kde.plasma.workspace.dbus),
  C++ helper plugin removed — no compiled component.
