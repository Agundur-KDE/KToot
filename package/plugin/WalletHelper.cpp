/*
 * SPDX-FileCopyrightText: 2026 Agundur <info@agundur.de>
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */
#include "WalletHelper.h"

#include <KWallet>
#include <QDebug>

using KWallet::Wallet;

namespace
{
const char FOLDER[] = "KToot";
}

WalletHelper::WalletHelper(QObject *parent)
    : QObject(parent)
{
}

WalletHelper::~WalletHelper()
{
    // Per KWallet API docs, deleting the Wallet is the correct way to close
    // it (its destructor unregisters the handle with kwalletd) — no
    // separate closeWallet() call needed or wanted here.
    delete m_wallet;
}

Wallet *WalletHelper::wallet()
{
    // A cached handle can go stale without any signal reaching us — e.g.
    // kwalletd6 restarting/crashing while this plugin stays loaded (real
    // case hit during testing: killing kwalletd6 to clear the timer-flood
    // left a dangling handle, and every call after that silently failed
    // with "could not create folder"). isOpen() catches that; discard and
    // reopen instead of returning a handle that looks valid but isn't.
    if (m_wallet && !m_wallet->isOpen()) {
        delete m_wallet;
        m_wallet = nullptr;
    }

    if (!m_wallet)
        m_wallet = Wallet::openWallet(Wallet::LocalWallet(), 0, Wallet::Synchronous);
    return m_wallet;
}

bool WalletHelper::ensureFolder()
{
    Wallet *w = wallet();
    if (!w)
        return false;

    if (!w->hasFolder(QLatin1String(FOLDER)) && !w->createFolder(QLatin1String(FOLDER))) {
        qWarning() << "WalletHelper: could not create the" << FOLDER << "folder";
        return false;
    }

    if (!w->setFolder(QLatin1String(FOLDER))) {
        qWarning() << "WalletHelper: could not select the" << FOLDER << "folder";
        return false;
    }

    return true;
}

bool WalletHelper::saveToken(const QString &instance, const QString &token)
{
    if (!ensureFolder())
        return false;

    return wallet()->writePassword(instance, token) == 0;
}

QString WalletHelper::readToken(const QString &instance)
{
    if (!ensureFolder())
        return QString();

    QString token;
    if (wallet()->readPassword(instance, token) != 0)
        return QString();

    return token;
}

bool WalletHelper::removeToken(const QString &instance)
{
    if (!ensureFolder())
        return false;

    if (wallet()->removeEntry(instance) != 0) {
        qWarning() << "WalletHelper: could not remove the stored token for" << instance;
        return false;
    }

    return true;
}
