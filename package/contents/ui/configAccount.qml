/*
 * SPDX-FileCopyrightText: 2026 Agundur <info@agundur.de>
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import "mastodon.js" as Mastodon

KCM.SimpleKCM {
    id: root

    property string cfg_Instance
    property string cfg_AccountHandle

    WalletDBus {
        id: wallet
    }

    // Tracks whether a token is already stored for the current instance,
    // so the field can show "already saved" instead of demanding re-entry.
    property bool hasStoredToken: false

    // Transient testAndSave() status (validation error, "testing…", HTTP
    // error). Empty means "no override" — the label falls back to deriving
    // its text/color from cfg_AccountHandle. Keeps the label's visual
    // properties bound to data instead of imperatively overwritten, so they
    // stay correct if cfg_AccountHandle ever changes from outside this file.
    property string statusMessage: ""
    property bool statusIsError: false

    function refreshStoredState() {
        wallet.readToken(cfg_Instance, function (token) {
            hasStoredToken = token.length > 0;
        });
    }

    Component.onCompleted: refreshStoredState()

    Kirigami.FormLayout {
        QtControls.TextField {
            id: instanceField
            Layout.fillWidth: true
            Kirigami.FormData.label: i18n("Instance:")
            text: cfg_Instance
            placeholderText: "https://mastodon.social"
            onEditingFinished: {
                cfg_Instance = text;
                root.refreshStoredState();
            }
        }

        QtControls.TextField {
            id: tokenField
            Layout.fillWidth: true
            Kirigami.FormData.label: i18n("Access token:")
            echoMode: TextInput.Password
            placeholderText: root.hasStoredToken
                ? i18n("(gespeichert — nur bei Änderung ausfüllen)")
                : i18n("Zugriffstoken einfügen")
        }

        RowLayout {
            Kirigami.FormData.label: ""
            QtControls.Button {
                text: i18n("Verbindung testen && speichern")
                icon.name: "network-connect"
                onClicked: root.testAndSave()
            }
        }

        QtControls.Label {
            id: statusLabel
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: root.statusMessage.length > 0
                ? root.statusMessage
                : (cfg_AccountHandle ? i18n("Verbunden als %1", cfg_AccountHandle) : i18n("Noch nicht verbunden"))
            color: root.statusMessage.length > 0
                ? (root.statusIsError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor)
                : (cfg_AccountHandle ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor)
        }
    }

    function setStatus(message, isError) {
        statusMessage = message;
        statusIsError = isError;
    }

    function testAndSave() {
        const instance = instanceField.text.replace(/\/+$/, "");
        const typedToken = tokenField.text;

        if (!instance) {
            root.setStatus(i18n("Bitte Instance-URL eintragen."), true);
            return;
        }

        if (!Mastodon.isValidInstanceUrl(instance)) {
            root.setStatus(i18n("Nur https://-Instances ohne Pfad/Zugangsdaten erlaubt."), true);
            return;
        }

        function proceedWithToken(tokenToTest) {
            if (!tokenToTest) {
                root.setStatus(i18n("Bitte Zugriffstoken einfügen."), true);
                return;
            }

            root.setStatus(i18n("Teste Verbindung …"), false);

            const xhr = new XMLHttpRequest();
            xhr.open("GET", instance + "/api/v1/accounts/verify_credentials");
            xhr.setRequestHeader("Authorization", "Bearer " + tokenToTest);
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== XMLHttpRequest.DONE)
                    return;

                if (xhr.status === 200) {
                    const data = JSON.parse(xhr.responseText);
                    const host = instance.replace(/^https?:\/\//, "");
                    cfg_AccountHandle = "@" + data.acct + "@" + host;
                    cfg_Instance = instance;

                    if (typedToken.length > 0) {
                        wallet.saveToken(instance, typedToken, function () {
                            root.refreshStoredState();
                        });
                    } else {
                        root.refreshStoredState();
                    }

                    tokenField.text = "";
                    // Clear the override — the label falls back to the
                    // cfg_AccountHandle binding, which already shows the
                    // same "Verbunden als %1" text.
                    root.setStatus("", false);
                } else {
                    root.setStatus(i18n("Fehler (%1): Token/Instance prüfen.", xhr.status), true);
                }
            };
            xhr.send();
        }

        if (typedToken.length > 0)
            proceedWithToken(typedToken);
        else
            wallet.readToken(instance, proceedWithToken);
    }
}
