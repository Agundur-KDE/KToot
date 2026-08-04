/*
 * SPDX-FileCopyrightText: 2026 Agundur <info@agundur.de>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 *
 */

import QtQuick 2.15
import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
        name: i18nc("@title", "Account")
        icon: "im-user"
        source: "configAccount.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Notifications")
        icon: "notifications"
        source: "configNotifications.qml"
    }
}
