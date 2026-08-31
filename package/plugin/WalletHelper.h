/*
 * SPDX-FileCopyrightText: 2026 Agundur <info@agundur.de>
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */
#pragma once

#include <QObject>
#include <QString>
#include <qqmlregistration.h>

namespace KWallet
{
class Wallet;
}

// Stores the Mastodon access token in KWallet, keyed by instance URL.
// Synchronous KWallet API: acceptable here since these calls only happen
// on config save / on-demand token read, not on a hot path.
//
// Reuses a single KWallet::Wallet handle for the lifetime of this singleton
// instead of opening/deleting one per call. Per KWallet API docs, deleting
// a Wallet is the correct way to close it (its destructor unregisters the
// handle) — that part wasn't wrong. But repeated open/close churn (e.g.
// several calls in quick succession around a connect/disconnect cycle) was
// observed to trigger a kwalletd6-side timer bug (QObject::killTimer()
// errors flooding the journal) — not a KToot API-usage bug, but reusing one
// handle avoids retriggering it.
class WalletHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit WalletHelper(QObject *parent = nullptr);
    ~WalletHelper() override;

    Q_INVOKABLE bool saveToken(const QString &instance, const QString &token);
    Q_INVOKABLE QString readToken(const QString &instance);
    Q_INVOKABLE void removeToken(const QString &instance);

private:
    // Returns the shared wallet handle, opening it on first use. nullptr on
    // failure (wallet unavailable/locked-and-cancelled) — callers must check.
    KWallet::Wallet *wallet();
    // Returns false (and leaves the folder unset) if the KToot folder
    // couldn't be created/selected — callers must not proceed to
    // read/write/remove an entry in that case, since it would silently
    // hit the wrong folder.
    bool ensureFolder();

    KWallet::Wallet *m_wallet = nullptr;
};
