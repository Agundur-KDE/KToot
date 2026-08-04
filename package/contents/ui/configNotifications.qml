/*
 * SPDX-FileCopyrightText: 2026 Agundur <info@agundur.de>
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property bool cfg_NotifyMentions
    property bool cfg_NotifyFollows
    property bool cfg_NotifyFavourites
    property bool cfg_NotifyReblogs

    Kirigami.FormLayout {
        QtControls.CheckBox {
            Kirigami.FormData.label: i18n("Anzeigen:")
            text: i18n("Erwähnungen / Antworten")
            checked: cfg_NotifyMentions
            onToggled: cfg_NotifyMentions = checked
        }
        QtControls.CheckBox {
            text: i18n("Neue Follower")
            checked: cfg_NotifyFollows
            onToggled: cfg_NotifyFollows = checked
        }
        QtControls.CheckBox {
            text: i18n("Favoriten")
            checked: cfg_NotifyFavourites
            onToggled: cfg_NotifyFavourites = checked
        }
        QtControls.CheckBox {
            text: i18n("Boosts (Reblogs)")
            checked: cfg_NotifyReblogs
            onToggled: cfg_NotifyReblogs = checked
        }
    }
}
