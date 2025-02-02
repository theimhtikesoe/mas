//
//  PurchaseDownloadObserver.swift
//  mas
//
//  Created by Andrew Naylor on 21/08/2015.
//  Copyright (c) 2015 Andrew Naylor. All rights reserved.
//

import CommerceKit
import StoreFoundation

@objc
class PurchaseDownloadObserver: NSObject, CKDownloadQueueObserver {
    let purchase: SSPurchase
    var completionHandler: (() -> Void)?
    var errorHandler: ((MASError) -> Void)?

    init(purchase: SSPurchase) {
        self.purchase = purchase
    }

    func downloadQueue(_ queue: CKDownloadQueue, statusChangedFor download: SSDownload) {
        guard
            download.metadata.itemIdentifier == purchase.itemIdentifier,
            let status = download.status
        else {
            return
        }

        if status.isFailed || status.isCancelled {
            queue.removeDownload(withItemIdentifier: download.metadata.itemIdentifier)
        } else {
            progress(status.progressState)
        }
    }

    func downloadQueue(_: CKDownloadQueue, changedWithAddition download: SSDownload) {
        guard download.metadata.itemIdentifier == purchase.itemIdentifier else {
            return
        }
        clearLine()
        printInfo("Downloading \(download.metadata.title)")
    }

    func downloadQueue(_: CKDownloadQueue, changedWithRemoval download: SSDownload) {
        guard
            download.metadata.itemIdentifier == purchase.itemIdentifier,
            let status = download.status
        else {
            return
        }

        clearLine()
        if status.isFailed {
            errorHandler?(.downloadFailed(error: status.error as NSError?))
        } else if status.isCancelled {
            errorHandler?(.cancelled)
        } else {
            printInfo("Installed \(download.metadata.title)")
            completionHandler?()
        }
    }
}

struct ProgressState {
    let percentComplete: Float
    let phase: String

    var percentage: String {
        // swiftlint:disable:next no_magic_numbers
        String(format: "%.1f%%", floor(percentComplete * 1000) / 10)
    }
}

func progress(_ state: ProgressState) {
    // Don't display the progress bar if we're not on a terminal
    guard isatty(fileno(stdout)) != 0 else {
        return
    }

    let barLength = 60

    let completeLength = Int(state.percentComplete * Float(barLength))
    var bar = ""
    for index in 0..<barLength {
        if index < completeLength {
            bar += "#"
        } else {
            bar += "-"
        }
    }
    clearLine()
    print("\(bar) \(state.percentage) \(state.phase)", terminator: "")
    fflush(stdout)
}

extension SSDownloadStatus {
    var progressState: ProgressState {
        ProgressState(percentComplete: percentComplete, phase: activePhase.phaseDescription)
    }
}

extension SSDownloadPhase {
    var phaseDescription: String {
        switch phaseType {
        case 0:
            return "Downloading"
        case 1:
            return "Installing"
        default:
            return "Waiting"
        }
    }
}
