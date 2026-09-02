import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.notification
import "mastodon.js" as Mastodon

PlasmoidItem {
    id: root

    WalletDBus {
        id: wallet
    }

    readonly property string instance: Plasmoid.configuration.Instance
    readonly property bool accountConnected: Plasmoid.configuration.AccountHandle.length > 0
    readonly property bool onDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar

    property string accessToken: ""
    property bool tokenLoaded: false
    property bool sessionActive: false
    property int followersCount: 0
    property int unreadCount: 0
    property string errorMessage: ""

    property ListModel notificationsModel: ListModel {}

    // Bumped on every instance switch and connect/disconnect. Async
    // callbacks capture the generation at request time and discard their
    // result if it no longer matches — otherwise a slow response from the
    // previous instance/session can land after a switch and contaminate the
    // new one (wrong follower count, wrong notifications, a notification
    // fired for the wrong account).
    property int pollGeneration: 0

    preferredRepresentation: onDesktop ? fullRepresentation : compactRepresentation

    Plasmoid.title: i18n("KToot")
    Plasmoid.icon: "ktoot"
    Plasmoid.status: unreadCount > 0 ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.PassiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    toolTipMainText: Plasmoid.title
    toolTipSubText: accountConnected
        ? i18n("%1 · %2 Follower · %3 ungelesen", Plasmoid.configuration.AccountHandle, followersCount, unreadCount)
        : i18n("Nicht verbunden — Einstellungen öffnen")

    Notification {
        id: mentionNotification
        componentName: "ktoot"
        eventId: "mention"
        iconName: "ktoot"
        flags: Notification.Persistent
    }

    function relativeTime(iso) {
        const s = Mastodon.secondsSince(iso);
        if (s < 60) return i18n("gerade eben");
        if (s < 3600) return i18n("vor %1 Min.", Math.floor(s / 60));
        if (s < 86400) return i18n("vor %1 Std.", Math.floor(s / 3600));
        return i18n("vor %1 Tg.", Math.floor(s / 86400));
    }

    function notifyItem(item) {
        const actor = "@" + Mastodon.notificationActor(item);
        let title;
        switch (item.type) {
        case "mention": title = i18n("%1 hat dich erwähnt", actor); break;
        case "quote": title = i18n("%1 hat deinen Post zitiert", actor); break;
        case "follow": title = i18n("%1 folgt dir jetzt", actor); break;
        case "favourite": title = i18n("%1 hat deinen Post favorisiert", actor); break;
        case "reblog": title = i18n("%1 hat deinen Post geboostet", actor); break;
        default: title = actor;
        }
        mentionNotification.title = title;
        mentionNotification.text = Mastodon.notificationText(item);
        mentionNotification.sendEvent();
    }

    function notifySummary(count) {
        mentionNotification.title = i18np("%1 neue Benachrichtigung", "%1 neue Benachrichtigungen", count);
        mentionNotification.text = i18n("Popup öffnen für Details");
        mentionNotification.sendEvent();
    }

    function describeError(err) {
        switch (Mastodon.classifyError(err)) {
        case "unauthorized": return i18n("Zugriffstoken ungültig — bitte neu verbinden.");
        case "rateLimited": return i18n("Instance blockt gerade (zu viele Anfragen) — versucht es später erneut.");
        case "serverError": return i18n("Instance antwortet mit einem Fehler.");
        case "network": return i18n("Verbindung zur Instance fehlgeschlagen.");
        default: return "";
        }
    }

    function ensureToken(callback) {
        if (tokenLoaded) {
            callback(accessToken);
            return;
        }
        wallet.readToken(instance, function (token) {
            accessToken = token;
            tokenLoaded = true;
            callback(token);
        });
    }

    onInstanceChanged: {
        tokenLoaded = false;
        accessToken = "";
        followersCount = 0;
        unreadCount = 0;
        errorMessage = "";
        notificationsModel.clear();
        pollGeneration++;
    }

    function connect() {
        sessionActive = true;
        errorMessage = "";
        pollGeneration++;
    }

    function disconnect() {
        sessionActive = false;
        accessToken = "";
        tokenLoaded = false;
        unreadCount = 0;
        errorMessage = "";
        pollGeneration++;
    }

    function markAllRead() {
        root.ensureToken(function (token) {
            if (!token || notificationsModel.count === 0)
                return;
            Mastodon.postMarker(instance, token, notificationsModel.get(0).notifId);
            unreadCount = 0;
        });
    }

    function poll() {
        if (!accountConnected)
            return;
        root.ensureToken(function (token) {
            if (!token)
                return;

            // Captured now, checked in every callback below: a response
            // that arrives after the instance/session has since changed is
            // stale and must not touch state for the new one.
            const gen = root.pollGeneration;

            Mastodon.fetchAccount(instance, token, function (err, account) {
                if (!root.sessionActive || gen !== root.pollGeneration)
                    return;
                if (err) {
                    root.errorMessage = root.describeError(err);
                    return;
                }
                if (account)
                    followersCount = account.followers_count;
            });

            Mastodon.fetchMarker(instance, token, function (markerErr, knownMarker) {
                if (!root.sessionActive || gen !== root.pollGeneration)
                    return;

                // Marker fetch failed: we can't tell what's actually new,
                // so treating a missing marker as "0" would flag the whole
                // page as unread. Skip this cycle instead, retry on the
                // next tick.
                if (markerErr) {
                    root.errorMessage = root.describeError(markerErr);
                    return;
                }

                const isFirstEverPoll = knownMarker === null;
                const excludeTypesList = Mastodon.excludeTypes(Plasmoid.configuration);

                // Display always shows the newest items regardless of read
                // state, so it's fetched separately from unread detection
                // below.
                Mastodon.fetchNotifications(instance, token, excludeTypesList, function (err, items) {
                    if (!root.sessionActive || gen !== root.pollGeneration)
                        return;
                    if (err || !Array.isArray(items)) {
                        root.errorMessage = root.describeError(err);
                        return;
                    }
                    root.errorMessage = "";

                    notificationsModel.clear();
                    for (let i = 0; i < Math.min(3, items.length); i++)
                        notificationsModel.append(Mastodon.toModelEntry(items[i]));

                    if (items.length > 0 && isFirstEverPoll) {
                        // Never polled this account before: establish a
                        // baseline instead of dumping the whole backlog as
                        // "new".
                        Mastodon.postMarker(instance, token, items[0].id);
                        unreadCount = 0;
                    }
                });

                if (isFirstEverPoll)
                    return;

                // Paginated, server-filtered (min_id) fetch — a single
                // limit=20 page here would silently drop anything past the
                // 20th item whenever more than 20 notifications piled up
                // since the last poll, so the actual unread count/list and
                // the marker we advance to must come from this, not from
                // the display fetch.
                Mastodon.fetchNewNotifications(instance, token, knownMarker, excludeTypesList, function (err, newItems) {
                    if (!root.sessionActive || gen !== root.pollGeneration)
                        return;
                    if (err || !Array.isArray(newItems)) {
                        root.errorMessage = root.describeError(err);
                        return;
                    }
                    root.errorMessage = "";

                    const unread = newItems.length;
                    if (unread === 0)
                        return;

                    if (unread > 3) {
                        root.notifySummary(unread);
                    } else {
                        for (const it of newItems)
                            root.notifyItem(it);
                    }

                    Mastodon.postMarker(instance, token, newItems[0].id);
                    unreadCount = root.onDesktop ? 0 : unread;
                });
            });
        });
    }

    Timer {
        interval: 75000
        running: root.accountConnected && root.sessionActive
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    // ── Desktop: header + last 3 notifications, always visible ─────────────
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: 340
        Layout.minimumHeight: 320
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Kirigami.PlaceholderMessage {
            visible: !root.accountConnected
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon.name: "im-user"
            text: i18n("Kein Mastodon-Account verbunden")
            explanation: i18n("Instance und Zugriffstoken eintragen.")
            helpfulAction: Kirigami.Action {
                icon.name: "configure"
                text: i18n("Konfigurieren")
                onTriggered: Plasmoid.internalAction("configure").trigger()
            }
        }

        RowLayout {
            visible: root.accountConnected
            Layout.fillWidth: true
            spacing: Kirigami.Units.gridUnit

            Kirigami.Icon {
                source: "ktoot"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                PlasmaComponents.Label {
                    text: Plasmoid.configuration.AccountHandle
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: i18np("%1 Follower", "%1 Follower", root.followersCount)
                    opacity: 0.7
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                display: PlasmaComponents.AbstractButton.IconOnly
                visible: root.sessionActive
                onClicked: root.poll()
                PlasmaComponents.ToolTip.text: i18n("Aktualisieren")
                PlasmaComponents.ToolTip.visible: hovered
            }

            PlasmaComponents.ToolButton {
                icon.name: root.sessionActive ? "network-disconnect" : "network-connect"
                text: root.sessionActive ? i18n("Disconnect") : i18n("Connect")
                onClicked: root.sessionActive ? root.disconnect() : root.connect()
            }
        }

        Kirigami.Separator {
            visible: root.accountConnected && root.sessionActive
            Layout.fillWidth: true
        }

        PlasmaComponents.Label {
            visible: root.accountConnected && root.sessionActive && root.errorMessage.length > 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: root.errorMessage
            color: Kirigami.Theme.negativeTextColor
            horizontalAlignment: Text.AlignHCenter
        }

        PlasmaComponents.Label {
            visible: root.accountConnected && !root.sessionActive
            Layout.fillWidth: true
            text: i18n("Getrennt — „Connect“ für aktuelle Benachrichtigungen")
            opacity: 0.6
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            Layout.fillHeight: root.accountConnected && !root.sessionActive
            Layout.fillWidth: true
        }

        PlasmaComponents.Label {
            visible: root.accountConnected && root.sessionActive && root.notificationsModel.count === 0
            Layout.fillWidth: true
            text: i18n("Keine aktuellen Benachrichtigungen")
            opacity: 0.6
            horizontalAlignment: Text.AlignHCenter
        }

        ListView {
            visible: root.accountConnected && root.sessionActive
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Kirigami.Units.smallSpacing
            model: root.notificationsModel

            delegate: RowLayout {
                width: ListView.view.width
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: model.icon
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    Layout.alignment: Qt.AlignTop
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: "@" + model.acct
                        font.bold: true
                    }
                    PlasmaComponents.Label {
                        visible: model.text.length > 0
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        text: model.text
                        opacity: 0.8
                    }
                    PlasmaComponents.Label {
                        text: root.relativeTime(model.createdAt)
                        opacity: 0.5
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }
            }
        }
    }

    // ── Panel: icon + unread badge only, click marks read ──────────────────
    compactRepresentation: Item {
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sessionActive ? root.markAllRead() : root.connect()
        }

        Kirigami.Icon {
            source: Plasmoid.icon
            anchors.fill: parent
        }

        Rectangle {
            visible: root.unreadCount > 0
            width: Math.max(badgeLabel.implicitWidth + Kirigami.Units.smallSpacing, height)
            height: Kirigami.Units.gridUnit * 0.9
            radius: height / 2
            color: Kirigami.Theme.negativeTextColor
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            Kirigami.Heading {
                id: badgeLabel
                level: 5
                anchors.centerIn: parent
                text: root.unreadCount > 99 ? "99+" : root.unreadCount
                color: "white"
            }
        }
    }
}
