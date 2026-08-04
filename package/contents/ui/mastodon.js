.pragma library

// Mastodon notification IDs are Snowflake-style decimal strings that exceed
// JS's safe integer range (2^53) — compare as digit strings, not Numbers.
function idGreaterThan(a, b) {
    a = String(a || "0");
    b = String(b || "0");
    if (a.length !== b.length)
        return a.length > b.length;
    return a > b;
}

function stripHtml(html) {
    return String(html || "")
        .replace(/<br\s*\/?>/gi, " ")
        .replace(/<\/p>/gi, " ")
        .replace(/<[^>]+>/g, "")
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&#39;/g, "'")
        .replace(/&quot;/g, '"')
        .replace(/\s+/g, " ")
        .trim();
}

function secondsSince(isoString) {
    if (!isoString)
        return 0;
    return Math.max(0, Math.floor((Date.now() - Date.parse(isoString)) / 1000));
}

function typeIcon(type) {
    switch (type) {
    case "mention": return "mail-replied-symbolic";
    case "follow": return "list-add-user";
    case "favourite": return "starred-symbolic";
    case "reblog": return "media-playlist-repeat";
    default: return "ktoot";
    }
}

// Notification types we know how to handle. Anything else (poll, status,
// follow_request, update, ...) is always excluded server-side.
const KNOWN_TYPES = ["mention", "follow", "favourite", "reblog"];

function excludeTypes(cfg) {
    const excl = [];
    if (!cfg.NotifyMentions) excl.push("mention");
    if (!cfg.NotifyFollows) excl.push("follow");
    if (!cfg.NotifyFavourites) excl.push("favourite");
    if (!cfg.NotifyReblogs) excl.push("reblog");
    for (const t of ["poll", "status", "follow_request", "update", "severed_relationships", "moderation_warning"])
        excl.push(t);
    return excl;
}

// No i18n() here — .pragma library scripts run in an isolated JS context
// without KI18n's context injection. Title formatting (which needs i18n)
// happens in main.qml; this just extracts the raw acct.
function notificationActor(item) {
    return item.account ? item.account.acct : "?";
}

function notificationText(item) {
    if (item.status && item.status.content)
        return stripHtml(item.status.content);
    return "";
}

function toModelEntry(item) {
    return {
        notifId: String(item.id),
        type: item.type,
        icon: typeIcon(item.type),
        acct: item.account ? item.account.acct : "?",
        text: notificationText(item),
        createdAt: item.created_at || ""
    };
}

function httpGet(url, token, callback) {
    const xhr = new XMLHttpRequest();
    xhr.open("GET", url);
    xhr.setRequestHeader("Authorization", "Bearer " + token);
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return;
        if (xhr.status >= 200 && xhr.status < 300) {
            try {
                callback(null, JSON.parse(xhr.responseText));
            } catch (e) {
                callback(e, null);
            }
        } else {
            callback(new Error("HTTP " + xhr.status), null);
        }
    };
    xhr.send();
}

function fetchAccount(instance, token, callback) {
    httpGet(instance + "/api/v1/accounts/verify_credentials", token, callback);
}

function fetchMarker(instance, token, callback) {
    httpGet(instance + "/api/v1/markers?timeline[]=notifications", token, function (err, data) {
        if (err) {
            callback(err, null);
            return;
        }
        const marker = data && data.notifications ? data.notifications.last_read_id : null;
        callback(null, marker);
    });
}

function postMarker(instance, token, notifId) {
    const xhr = new XMLHttpRequest();
    xhr.open("POST", instance + "/api/v1/markers");
    xhr.setRequestHeader("Authorization", "Bearer " + token);
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
    xhr.send("notifications[last_read_id]=" + encodeURIComponent(notifId));
}

function fetchNotifications(instance, token, excludeTypesList, callback) {
    let url = instance + "/api/v1/notifications?limit=20";
    for (const t of excludeTypesList)
        url += "&exclude_types[]=" + encodeURIComponent(t);
    httpGet(url, token, callback);
}
