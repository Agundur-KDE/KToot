/*
 * SPDX-FileCopyrightText: 2026 Agundur <info@agundur.de>
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */
#include "WalletHelper.h"

#include <KWallet>

using KWallet::Wallet;

namespace
{
const char FOLDER[] = "KToot";
}

WalletHelper::WalletHelper(QObject *parent)
    : QObject(parent)
{
}

bool WalletHelper::saveToken(const QString &instance, const QString &token)
{
    Wallet *wallet = Wallet::openWallet(Wallet::LocalWallet(), 0, Wallet::Synchronous);
    if (!wallet)
        return false;

    if (!wallet->hasFolder(QLatin1String(FOLDER)))
        wallet->createFolder(QLatin1String(FOLDER));
    wallet->setFolder(QLatin1String(FOLDER));

    const bool ok = wallet->writePassword(instance, token) == 0;
    delete wallet;
    return ok;
}

QString WalletHelper::readToken(const QString &instance)
{
    Wallet *wallet = Wallet::openWallet(Wallet::LocalWallet(), 0, Wallet::Synchronous);
    if (!wallet)
        return QString();

    if (!wallet->hasFolder(QLatin1String(FOLDER))) {
        delete wallet;
        return QString();
    }
    wallet->setFolder(QLatin1String(FOLDER));

    QString token;
    wallet->readPassword(instance, token);
    delete wallet;
    return token;
}

void WalletHelper::removeToken(const QString &instance)
{
    Wallet *wallet = Wallet::openWallet(Wallet::LocalWallet(), 0, Wallet::Synchronous);
    if (!wallet)
        return;

    if (wallet->hasFolder(QLatin1String(FOLDER))) {
        wallet->setFolder(QLatin1String(FOLDER));
        wallet->removeEntry(instance);
    }
    delete wallet;
}
