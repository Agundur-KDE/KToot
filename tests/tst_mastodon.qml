import QtQuick
import QtTest
import "../package/contents/ui/mastodon.js" as Mastodon

TestCase {
    name: "MastodonJs"

    function test_idGreaterThan_data() {
        return [
            { tag: "longer-is-greater", a: "12345678901234567890", b: "9876543210", expected: true },
            { tag: "shorter-is-smaller", a: "9876543210", b: "12345678901234567890", expected: false },
            { tag: "same-length-lexicographic", a: "20", b: "19", expected: true },
            { tag: "equal", a: "42", b: "42", expected: false },
            { tag: "null-marker-treated-as-zero", a: "1", b: null, expected: true },
        ];
    }
    function test_idGreaterThan(data) {
        compare(Mastodon.idGreaterThan(data.a, data.b), data.expected);
    }

    function test_isValidInstanceUrl_data() {
        return [
            { tag: "https-plain-host", url: "https://mastodon.social", expected: true },
            { tag: "https-with-port", url: "https://example.org:8443", expected: true },
            { tag: "http-rejected", url: "http://mastodon.social", expected: false },
            { tag: "javascript-scheme-rejected", url: "javascript:alert(1)", expected: false },
            { tag: "embedded-credentials-rejected", url: "https://user:pass@mastodon.social", expected: false },
            { tag: "path-rejected", url: "https://mastodon.social/api", expected: false },
            { tag: "trailing-slash-rejected", url: "https://mastodon.social/", expected: false },
            { tag: "empty-rejected", url: "", expected: false },
        ];
    }
    function test_isValidInstanceUrl(data) {
        compare(Mastodon.isValidInstanceUrl(data.url), data.expected);
    }

    function test_notificationText_hides_content_behind_content_warning() {
        const item = {
            status: {
                sensitive: true,
                spoiler_text: "CW: Spoiler",
                content: "<p>Das eigentliche geheime Zeug</p>",
            },
        };
        compare(Mastodon.notificationText(item), "CW: Spoiler");
    }

    function test_notificationText_shows_plain_content_when_not_sensitive() {
        const item = {
            status: {
                sensitive: false,
                spoiler_text: "",
                content: "<p>Hallo Welt</p>",
            },
        };
        compare(Mastodon.notificationText(item), "Hallo Welt");
    }

    function test_notificationText_sensitive_without_spoiler_text_hides_content() {
        const item = {
            status: {
                sensitive: true,
                spoiler_text: "",
                content: "<p>Das eigentliche geheime Zeug</p>",
            },
        };
        compare(Mastodon.notificationText(item), "");
    }

    function test_classifyError_data() {
        return [
            { tag: "no-error", err: null, expected: "none" },
            { tag: "unauthorized-401", err: { httpStatus: 401 }, expected: "unauthorized" },
            { tag: "forbidden-403", err: { httpStatus: 403 }, expected: "unauthorized" },
            { tag: "rate-limited-429", err: { httpStatus: 429 }, expected: "rateLimited" },
            { tag: "server-error-500", err: { httpStatus: 500 }, expected: "serverError" },
            { tag: "network-error-no-status", err: new Error("boom"), expected: "network" },
        ];
    }
    function test_classifyError(data) {
        compare(Mastodon.classifyError(data.err), data.expected);
    }

    function test_secondsSince_invalid_date_returns_zero() {
        compare(Mastodon.secondsSince("not-a-date"), 0);
    }

    function test_excludeTypes_respects_config_flags() {
        const cfg = {
            NotifyMentions: false,
            NotifyFollows: true,
            NotifyFavourites: true,
            NotifyReblogs: true,
        };
        const excl = Mastodon.excludeTypes(cfg);
        verify(excl.indexOf("mention") !== -1);
        verify(excl.indexOf("quote") !== -1);
        verify(excl.indexOf("follow") === -1);
    }
}
