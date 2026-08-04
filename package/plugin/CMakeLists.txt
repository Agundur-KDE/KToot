find_package(Qt6 REQUIRED COMPONENTS Core Qml)
find_package(KF6 REQUIRED COMPONENTS Wallet)

include(ECMQmlModule)

ecm_add_qml_module(ktootplugin
    URI de.agundur.ktoot
    VERSION 1.0
    GENERATE_PLUGIN_SOURCE
)

target_sources(ktootplugin PRIVATE
    WalletHelper.cpp WalletHelper.h
)

target_link_libraries(ktootplugin PRIVATE Qt6::Core Qt6::Qml KF6::Wallet)

ecm_finalize_qml_module(ktootplugin)
