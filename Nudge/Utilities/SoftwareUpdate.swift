//
//  SoftwareUpdate.swift
//  Nudge
//
//  Created by Rory Murdock on 2/10/21.
//

import Foundation

class SoftwareUpdate {
    func List() -> String {
        let task = Process()
        task.launchPath = "/usr/sbin/softwareupdate"
        task.arguments = ["--list", "--all"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
        } catch {
            let msg = "Error listing software updates"
            softwareupdateListLog.error("\(msg, privacy: .public)")
        }

        task.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(decoding: outputData, as: UTF8.self)
        let error = String(decoding: errorData, as: UTF8.self)

        if task.terminationStatus != 0 {
            softwareupdateListLog.error("Error listing software updates: \(error, privacy: .public)")
            return error
        } else {
            softwareupdateListLog.info("\(output, privacy: .public)")
            return output
        }

    }

    func Download() {
        softwareupdateDownloadLog.notice("enforceMinorUpdates: \(enforceMinorUpdates, privacy: .public)")

        if Utils().getCPUTypeString() == "Apple Silicon" && Utils().requireMajorUpgrade() == false {
            let msg = "Apple Silicon devices do not support automated softwareupdate downloads for minor updates. Please use MDM."
            softwareupdateListLog.debug("\(msg, privacy: .public)")
            return
        }
        
        if Utils().requireMajorUpgrade() {
            if actionButtonPath != nil {
                return
            }

            if attemptToFetchMajorUpgrade == true {
                if majorUpgradeAppPathExists {
                    let msg = "found major upgrade application - skipping download"
                    softwareupdateListLog.notice("\(msg, privacy: .public)")
                    return
                }

                if majorUpgradeBackupAppPathExists {
                    let msg = "found backup major upgrade application - skipping download"
                    softwareupdateListLog.notice("\(msg, privacy: .public)")
                    return
                }
                
                let msg = "device requires major upgrade - attempting download"
                softwareupdateListLog.notice("\(msg, privacy: .public)")
                let task = Process()
                task.launchPath = "/usr/sbin/softwareupdate"
                task.arguments = ["--fetch-full-installer", "--full-installer-version", requiredMinimumOSVersionNormalized]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                task.standardOutput = outputPipe
                task.standardError = errorPipe
                
                do {
                    try task.run()
                } catch {
                    let msg = "Error downloading software update"
                    softwareupdateListLog.error("\(msg, privacy: .public)")
                }
                
                task.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(decoding: outputData, as: UTF8.self)
                let _ = String(decoding: errorData, as: UTF8.self)
                
                if task.terminationStatus != 0 {
                    softwareupdateDownloadLog.error("Error downloading software update: \(output, privacy: .public)")
                } else {
                    let msg = "softwareupdate successfully downloaded available update application - updating application paths"
                    softwareupdateListLog.notice("\(msg, privacy: .public)")
                    softwareupdateDownloadLog.info("\(output, privacy: .public)")
                    fetchMajorUpgradeSuccessful = true
                    majorUpgradeAppPathExists = FileManager.default.fileExists(atPath: majorUpgradeAppPath)
                    majorUpgradeBackupAppPathExists = FileManager.default.fileExists(atPath: Utils().getBackupMajorUpgradeAppPath())
                }
            } else {
                    let msg = "device requires major upgrade but attemptToFetchMajorUpgrade is False - skipping download"
                    softwareupdateListLog.notice("\(msg, privacy: .public)")
            }
        } else {
            if disableSoftwareUpdateWorkflow {
                let msg = "Skip running softwareupdate because it's disabled by a preference."
                uiLog.info("\(msg, privacy: .public)")
            }
            let softwareupdateList = self.List()
            var updateLabel = ""
            for update in softwareupdateList.components(separatedBy: "\n") {
                if update.contains("Label:") {
                    updateLabel = update.components(separatedBy: ": ")[1]
                }
            }
            
            if softwareupdateList.contains(requiredMinimumOSVersionNormalized) && updateLabel.isEmpty == false {
                softwareupdateListLog.notice("softwareupdate found \(updateLabel, privacy: .public) available for download - attempting download")
                let task = Process()
                task.launchPath = "/usr/sbin/softwareupdate"
                task.arguments = ["--download", "\(updateLabel)"]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                task.standardOutput = outputPipe
                task.standardError = errorPipe
                
                do {
                    try task.run()
                } catch {
                    let msg = "Error downloading software update"
                    softwareupdateListLog.error("\(msg, privacy: .public)")
                }
                
                task.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(decoding: outputData, as: UTF8.self)
                let error = String(decoding: errorData, as: UTF8.self)
                
                if task.terminationStatus != 0 {
                    softwareupdateDownloadLog.error("Error downloading software updates: \(error, privacy: .public)")
                } else {
                    let msg = "softwareupdate successfully downloaded available update"
                    softwareupdateListLog.notice("\(msg, privacy: .public)")
                    softwareupdateDownloadLog.info("\(output, privacy: .public)")
                }
            } else {
                softwareupdateListLog.notice("softwareupdate did not find \(requiredMinimumOSVersionNormalized, privacy: .public) available for download - skipping download attempt")
            }
        }
    }
}
