/*
 * SPDX-FileCopyrightText: 2026 Agundur <info@agundur.de>
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// Talks to kwalletd6 over its native D-Bus interface instead of wrapping
// KF6::Wallet in a compiled C++ plugin. This is a plain (non-singleton) QML
// type — WalletHelper.qml { id: wallet } is meant to be instantiated once
// per file that needs it, same as the old WalletHelper QML_SINGLETON, just
// without a shared C++ object.
//
// Value types like DBus.int64() and QML singletons (DBus.SessionBus) are
// only usable from a real QML component — a .pragma library JS file (like
// mastodon.js) can only import QML *singletons*, not constructible value
// types, so this logic can't live there.
QtObject {
    id: root

    readonly property string service: "org.kde.kwalletd6"
    readonly property string objectPath: "/modules/kwalletd6"
    readonly property string iface: "org.kde.KWallet"
    readonly property string walletName: "kdewallet"
    readonly property string appId: "ktoot"
    readonly property string folder: "KToot"

    function call(member, signature, args, resolve, reject) {
        DBus.SessionBus.asyncCall(
            {
                service: root.service,
                path: root.objectPath,
                iface: root.iface,
                member: member,
                signature: signature,
                arguments: args
            },
            function (result) {
                // The callback-style asyncCall() overload still hands back
                // a DBusPendingReply (already finished by the time resolve
                // fires) rather than the unwrapped return value — unwrap it
                // here so every caller above just deals with plain values.
                const value = (result && typeof result === "object" && "value" in result) ? result.value : result;
                resolve(value);
            },
            function (error) {
                console.warn("KTOOT-DBUS-RAW: " + member + " REJECTED", error.name, error.message);
                if (reject)
                    reject(error);
            }
        );
    }

    // wId=0 ("no parent window") lets kwalletd6 still show its own unlock
    // dialog if the wallet is locked; it just won't be transient for a
    // specific window. Calling open() every time (rather than caching a
    // handle across the plasmoid's lifetime, like the old C++ helper did)
    // means there's no stale-handle state to go wrong if kwalletd6 restarts
    // — the exact bug class the old WalletHelper had to work around.
    function openWallet(callback) {
        root.call("open", "(sxs)", [root.walletName, new DBus.int64(0), root.appId], function (handle) {
            const h = Number(handle);
            if (h < 0) {
                callback(new Error("KWallet open() returned handle " + h));
                return;
            }
            callback(null, h);
        }, function (error) {
            callback(error instanceof Error ? error : new Error((error && error.message) || "KWallet open() failed"));
        });
    }

    function ensureFolder(handle, callback) {
        root.call("hasFolder", "(iss)", [handle, root.folder, root.appId], function (exists) {
            if (Boolean(exists)) {
                callback(null);
                return;
            }
            root.call("createFolder", "(iss)", [handle, root.folder, root.appId], function (ok) {
                callback(Boolean(ok) ? null : new Error("could not create the KToot KWallet folder"));
            }, function (error) {
                callback(error instanceof Error ? error : new Error("could not create the KToot KWallet folder"));
            });
        }, function (error) {
            callback(error instanceof Error ? error : new Error("could not query the KToot KWallet folder"));
        });
    }

    // Mirrors the old WalletHelper C++ singleton's API, just async.

    function readToken(instance, callback) {
        root.openWallet(function (err, handle) {
            if (err) {
                callback("");
                return;
            }
            // A missing folder/entry reads back as an empty string rather
            // than an error — same "no token yet" case either way.
            root.call("readPassword", "(isss)", [handle, root.folder, instance, root.appId], function (value) {
                callback(String(value || ""));
            }, function () {
                callback("");
            });
        });
    }

    function saveToken(instance, token, callback) {
        root.openWallet(function (err, handle) {
            if (err) {
                callback(false);
                return;
            }
            root.ensureFolder(handle, function (folderErr) {
                if (folderErr) {
                    callback(false);
                    return;
                }
                root.call("writePassword", "(issss)", [handle, root.folder, instance, token, root.appId], function (status) {
                    callback(Number(status) === 0);
                }, function () {
                    callback(false);
                });
            });
        });
    }

    function removeToken(instance, callback) {
        root.openWallet(function (err, handle) {
            if (err) {
                callback(false);
                return;
            }
            root.call("removeEntry", "(isss)", [handle, root.folder, instance, root.appId], function (status) {
                callback(Number(status) === 0);
            }, function () {
                callback(false);
            });
        });
    }
}
