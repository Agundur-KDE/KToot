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
    const parsed = Date.parse(isoString);
    if (Number.isNaN(parsed))
        return 0;
    return Math.max(0, Math.floor((Date.now() - parsed) / 1000));
}

// "Activity on your posts" (mention/favourite/reblog) all share the KToot
// waves glyph — simpler than three unrelated theme icons. Follow is the odd
// one out (not post-related) and keeps a normal person icon.
function typeIcon(type) {
    switch (type) {
    case "follow": return "list-add-user";
    case "mention":
    case "favourite":
    case "reblog":
    case "quote":
        // ListModel.append() loses the QUrl type from Qt.resolvedUrl() —
        // store as a plain string instead.
        return String(Qt.resolvedUrl("../icons/ktoot-waves.png"));
    default: return "ktoot";
    }
}

function excludeTypes(cfg) {
    const excl = [];
    // "quote" (Mastodon's quote-post notification) rides on the Mentions
    // toggle — both mean "someone referenced your post", no separate UI for it.
    if (!cfg.NotifyMentions) { excl.push("mention"); excl.push("quote"); }
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

// A status behind a content warning (status.sensitive) must never leak its
// body into a desktop notification or the panel list — only the author's
// own spoiler_text (the warning label itself) is safe to show.
function notificationText(item) {
    if (!item.status)
        return "";
    if (item.status.sensitive)
        return String(item.status.spoiler_text || "");
    if (item.status.content)
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

// Accepts only "https://host" or "https://host:port" — no path, query,
// fragment, or embedded credentials. The Bearer token goes to this origin
// on every request, so this is checked both in the config UI and again
// here, since Plasmoid.configuration can be edited outside the config UI.
function isValidInstanceUrl(url) {
    return /^https:\/\/[a-zA-Z0-9.-]+(:[0-9]+)?$/.test(String(url || ""));
}

function buildUrl(instance, path) {
    if (!isValidInstanceUrl(instance))
        return null;
    return instance + path;
}

// Classifies a fetch error into a code main.qml can turn into user-facing
// text (i18n() isn't available in this isolated .pragma context — see the
// note on notificationActor()). httpStatus is set by httpGet() below on any
// non-2xx response; its absence means a transport-level failure (DNS,
// timeout, connection refused) or a JSON.parse() error.
function classifyError(err) {
    if (!err)
        return "none";
    if (err.httpStatus === 401 || err.httpStatus === 403)
        return "unauthorized";
    if (err.httpStatus === 429)
        return "rateLimited";
    if (err.httpStatus)
        return "serverError";
    return "network";
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
            const err = new Error("HTTP " + xhr.status);
            err.httpStatus = xhr.status;
            callback(err, null);
        }
    };
    xhr.send();
}

function fetchAccount(instance, token, callback) {
    const url = buildUrl(instance, "/api/v1/accounts/verify_credentials");
    if (!url) {
        callback(new Error("invalid instance url"), null);
        return;
    }
    httpGet(url, token, callback);
}

function fetchMarker(instance, token, callback) {
    const url = buildUrl(instance, "/api/v1/markers?timeline[]=notifications");
    if (!url) {
        callback(new Error("invalid instance url"), null);
        return;
    }
    httpGet(url, token, function (err, data) {
        if (err) {
            callback(err, null);
            return;
        }
        const marker = data && data.notifications ? data.notifications.last_read_id : null;
        callback(null, marker);
    });
}

function postMarker(instance, token, notifId) {
    const url = buildUrl(instance, "/api/v1/markers");
    if (!url) {
        console.warn("KToot: postMarker skipped — invalid instance url");
        return;
    }
    const xhr = new XMLHttpRequest();
    xhr.open("POST", url);
    xhr.setRequestHeader("Authorization", "Bearer " + token);
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return;
        if (xhr.status < 200 || xhr.status >= 300)
            console.warn("KToot: postMarker failed with HTTP " + xhr.status + " — " + xhr.responseText);
    };
    xhr.send("notifications[last_read_id]=" + encodeURIComponent(notifId));
}

// Latest page only — used to populate the "last 3 notifications" display,
// which always shows the newest items regardless of read state.
function fetchNotifications(instance, token, excludeTypesList, callback) {
    let url = buildUrl(instance, "/api/v1/notifications?limit=20");
    if (!url) {
        callback(new Error("invalid instance url"), null);
        return;
    }
    for (const t of excludeTypesList)
        url += "&exclude_types[]=" + encodeURIComponent(t);
    httpGet(url, token, callback);
}

// Everything newer than minId, paginated via max_id. A single limit=20 page
// silently dropped anything beyond the 20th item whenever more than 20
// notifications had piled up since the last poll — this walks pages (using
// the server-side min_id filter, so client-side ID comparison isn't needed
// to find the boundary) until a short page signals "no more", capped at
// maxPages so one very stale marker can't turn a poll into an unbounded
// request storm.
function fetchNewNotifications(instance, token, minId, excludeTypesList, callback) {
    const limit = 20;
    const maxPages = 5;
    let all = [];

    function fetchPage(maxId, pageNum) {
        let url = buildUrl(instance, "/api/v1/notifications?limit=" + limit);
        if (!url) {
            callback(new Error("invalid instance url"), null);
            return;
        }
        for (const t of excludeTypesList)
            url += "&exclude_types[]=" + encodeURIComponent(t);
        if (minId)
            url += "&min_id=" + encodeURIComponent(minId);
        if (maxId)
            url += "&max_id=" + encodeURIComponent(maxId);

        httpGet(url, token, function (err, items) {
            if (err || !items) {
                callback(err, null);
                return;
            }
            all = all.concat(items);
            const pageWasFull = items.length === limit;
            if (pageWasFull && pageNum < maxPages)
                fetchPage(items[items.length - 1].id, pageNum + 1);
            else
                callback(null, all);
        });
    }

    fetchPage(null, 1);
}
