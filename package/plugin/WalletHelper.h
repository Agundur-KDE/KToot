/*
 * SPDX-FileCopyrightText: 2026 Agundur <info@agundur.de>
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */
#pragma once

#include <QObject>
#include <QString>
#include <qqmlregistration.h>

// Stores the Mastodon access token in KWallet, keyed by instance URL.
// Synchronous KWallet API: acceptable here since these calls only happen
// on config save / on-demand token read, not on a hot path.
class WalletHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit WalletHelper(QObject *parent = nullptr);

    Q_INVOKABLE bool saveToken(const QString &instance, const QString &token);
    Q_INVOKABLE QString readToken(const QString &instance);
    Q_INVOKABLE void removeToken(const QString &instance);
};
