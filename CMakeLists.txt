cmake_minimum_required(VERSION 3.16)
project(ktoot)

set(QT_MIN_VERSION "6.7.0")
set(KF6_MIN_VERSION "6.10.0")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMFindQmlModule)
include(ECMQmlModule)
include(ECMAddTests)
include(ECMInstallIcons)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
    Core
    Quick
    Test
    QuickTest
)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    Config
    I18n
    KCMUtils
    Wallet
    Notifications
    IconThemes
)

enable_testing()

add_test(NAME validate-metadata
    COMMAND python3 ${CMAKE_SOURCE_DIR}/scripts/validate-metadata.py
                    ${CMAKE_SOURCE_DIR}/package/metadata.json
)

ki18n_install(translate
    INSTALL_DESTINATION ${KDE_INSTALL_LOCALEDIR}
)

add_subdirectory(package)
add_subdirectory(tests)

install(FILES
    ${CMAKE_SOURCE_DIR}/package/metadata/notifyrc/ktoot.notifyrc
    DESTINATION ${KDE_INSTALL_KNOTIFYRCDIR}
)

ecm_install_icons(ICONS
    ${CMAKE_SOURCE_DIR}/package/metadata/icons/16-apps-ktoot.png
    ${CMAKE_SOURCE_DIR}/package/metadata/icons/32-apps-ktoot.png
    ${CMAKE_SOURCE_DIR}/package/metadata/icons/64-apps-ktoot.png
    ${CMAKE_SOURCE_DIR}/package/metadata/icons/128-apps-ktoot.png
    DESTINATION ${KDE_INSTALL_ICONDIR}
    THEME hicolor
)

# Only ship metadata.json + contents/ (QML, config, translations) — a blanket
# install(DIRECTORY package/) would also ship plugin/*.cpp,h,CMakeLists.txt
# as inert data files next to the actually-used compiled plugin, which
# ecm_add_qml_module already installs to the Qt QML plugin dir above.
install(FILES package/metadata.json
        DESTINATION ${KDE_INSTALL_DATADIR}/plasma/plasmoids/de.agundur.ktoot)

install(DIRECTORY package/contents/
        DESTINATION ${KDE_INSTALL_DATADIR}/plasma/plasmoids/de.agundur.ktoot/contents)
