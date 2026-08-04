/*
 * SPDX-FileCopyrightText: 2026 Agundur <info@agundur.de>
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import de.agundur.ktoot

KCM.SimpleKCM {
    id: root

    property string cfg_Instance
    property string cfg_AccountHandle

    // Tracks whether a token is already stored for the current instance,
    // so the field can show "already saved" instead of demanding re-entry.
    property bool hasStoredToken: false

    function refreshStoredState() {
        hasStoredToken = WalletHelper.readToken(cfg_Instance).length > 0;
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
            text: cfg_AccountHandle
                ? i18n("Verbunden als %1", cfg_AccountHandle)
                : i18n("Noch nicht verbunden")
            color: cfg_AccountHandle ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
        }
    }

    function testAndSave() {
        const instance = instanceField.text.replace(/\/+$/, "");
        const typedToken = tokenField.text;

        if (!instance) {
            statusLabel.text = i18n("Bitte Instance-URL eintragen.");
            statusLabel.color = Kirigami.Theme.negativeTextColor;
            return;
        }

        const tokenToTest = typedToken.length > 0 ? typedToken : WalletHelper.readToken(instance);
        if (!tokenToTest) {
            statusLabel.text = i18n("Bitte Zugriffstoken einfügen.");
            statusLabel.color = Kirigami.Theme.negativeTextColor;
            return;
        }

        statusLabel.text = i18n("Teste Verbindung …");
        statusLabel.color = Kirigami.Theme.disabledTextColor;

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

                if (typedToken.length > 0)
                    WalletHelper.saveToken(instance, typedToken);

                tokenField.text = "";
                root.refreshStoredState();
                statusLabel.text = i18n("Verbunden als %1", cfg_AccountHandle);
                statusLabel.color = Kirigami.Theme.positiveTextColor;
            } else {
                statusLabel.text = i18n("Fehler (%1): Token/Instance prüfen.", xhr.status);
                statusLabel.color = Kirigami.Theme.negativeTextColor;
            }
        };
        xhr.send();
    }
}
