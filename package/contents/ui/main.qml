import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.notification
import de.agundur.ktoot
import "mastodon.js" as Mastodon

PlasmoidItem {
    id: root

    readonly property string instance: Plasmoid.configuration.Instance
    readonly property bool accountConnected: Plasmoid.configuration.AccountHandle.length > 0
    readonly property bool onDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar

    property string accessToken: ""
    property bool tokenLoaded: false
    property int followersCount: 0
    property int unreadCount: 0

    property ListModel notificationsModel: ListModel {}

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
        case "follow": title = i18n("%1 folgt dir jetzt", actor); break;
        case "favourite": title = i18n("%1 hat deinen Post favorisiert", actor); break;
        case "reblog": title = i18n("%1 hat deinen Post geboostet", actor); break;
        default: title = actor;
        }
        mentionNotification.title = title;
        mentionNotification.text = Mastodon.notificationText(item);
        mentionNotification.sendEvent();
    }

    function ensureToken() {
        if (!tokenLoaded) {
            accessToken = WalletHelper.readToken(instance);
            tokenLoaded = true;
        }
        return accessToken;
    }

    onInstanceChanged: {
        tokenLoaded = false;
        accessToken = "";
    }

    function markAllRead() {
        const token = ensureToken();
        if (!token || notificationsModel.count === 0)
            return;
        Mastodon.postMarker(instance, token, notificationsModel.get(0).notifId);
        unreadCount = 0;
    }

    function poll() {
        if (!accountConnected)
            return;
        const token = ensureToken();
        if (!token)
            return;

        Mastodon.fetchAccount(instance, token, function (err, account) {
            if (!err && account)
                followersCount = account.followers_count;
        });

        Mastodon.fetchMarker(instance, token, function (markerErr, knownMarker) {
            const isFirstEverPoll = !markerErr && knownMarker === null;

            Mastodon.fetchNotifications(instance, token, Mastodon.excludeTypes(Plasmoid.configuration), function (err, items) {
                if (err || !items)
                    return;

                notificationsModel.clear();
                for (let i = 0; i < Math.min(3, items.length); i++)
                    notificationsModel.append(Mastodon.toModelEntry(items[i]));

                if (items.length === 0)
                    return;

                const newestId = items[0].id;

                if (isFirstEverPoll) {
                    // Never polled this account before: establish a baseline
                    // instead of dumping the whole backlog as "new".
                    Mastodon.postMarker(instance, token, newestId);
                    unreadCount = 0;
                    return;
                }

                let unread = 0;
                for (const it of items) {
                    if (Mastodon.idGreaterThan(it.id, knownMarker)) {
                        unread++;
                        root.notifyItem(it);
                    }
                }

                if (root.onDesktop) {
                    if (unread > 0)
                        Mastodon.postMarker(instance, token, newestId);
                    unreadCount = 0;
                } else {
                    unreadCount = unread;
                }
            });
        });
    }

    Timer {
        interval: 75000
        running: root.accountConnected
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    // ── Desktop: header + last 3 notifications, always visible ─────────────
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: 340
        Layout.minimumHeight: 320
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Kirigami.PlaceholderMessage {
            visible: !root.accountConnected
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon.name: "im-user"
            text: i18n("Kein Mastodon-Account verbunden")
            explanation: i18n("Rechtsklick → Einstellungen, um Instance und Zugriffstoken einzutragen.")
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
        }

        Kirigami.Separator {
            visible: root.accountConnected
            Layout.fillWidth: true
        }

        PlasmaComponents.Label {
            visible: root.accountConnected && root.notificationsModel.count === 0
            Layout.fillWidth: true
            text: i18n("Keine aktuellen Benachrichtigungen")
            opacity: 0.6
            horizontalAlignment: Text.AlignHCenter
        }

        ListView {
            visible: root.accountConnected
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
            onClicked: root.markAllRead()
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
