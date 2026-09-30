import UIKit
import WebKit

/// One foreground WebUI session owns its temporary exports; nothing is automatically resumed.
@MainActor final class WorkspaceDownloads:NSObject,WKDownloadDelegate {
    weak var web:WKWebView?
    private var active = true
    private var pending:[ObjectIdentifier:WKDownload] = [:]
    private var files:[ObjectIdentifier:URL] = [:]
    private var directories:Set<URL> = []
    private weak var sharing:UIActivityViewController?
    init(web:WKWebView?) { self.web = web }
    func accept(_ download:WKDownload) {
        guard active else { download.cancel { _ in }; return }
        pending[ObjectIdentifier(download)] = download; download.delegate = self
    }
    func clear() {
        active = false
        for download in pending.values { download.delegate = nil; download.cancel { _ in } }
        pending.removeAll(); files.removeAll()
        sharing?.dismiss(animated:false)
        for directory in directories { try? FileManager.default.removeItem(at:directory) }
        directories.removeAll()
    }
    func download(_ download:WKDownload,decideDestinationUsing response:URLResponse,suggestedFilename:String,completionHandler:@escaping @MainActor @Sendable (URL?)->Void) {
        guard active,(response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true else { completionHandler(nil); return }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("a0-export-"+UUID().uuidString,isDirectory:true)
        var name = (suggestedFilename as NSString).lastPathComponent
            .components(separatedBy:CharacterSet.controlCharacters.union(CharacterSet(charactersIn:"/\\:"))).joined(separator:"_")
        while name.utf8.count > 180 { name.removeLast() }
        if name.isEmpty || name == "." || name == ".." { name = "Export" }
        do {
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false,attributes:[.protectionKey:FileProtectionType.complete])
            var protected = directory; var values = URLResourceValues(); values.isExcludedFromBackup = true
            try protected.setResourceValues(values)
            let file = directory.appendingPathComponent(name)
            directories.insert(directory); files[ObjectIdentifier(download)] = file
            completionHandler(file)
        } catch { try? FileManager.default.removeItem(at:directory); completionHandler(nil) }
    }
    func download(_ download:WKDownload,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,decisionHandler:@escaping @MainActor @Sendable (WKDownload.RedirectPolicy)->Void) {
        decisionHandler(.cancel)
    }
    func download(_ download:WKDownload,didReceive challenge:URLAuthenticationChallenge,completionHandler:@escaping @MainActor @Sendable (URLSession.AuthChallengeDisposition,URLCredential?)->Void) {
        completionHandler(.performDefaultHandling,nil)
    }
    func downloadDidFinish(_ download:WKDownload) {
        let id = ObjectIdentifier(download); pending[id] = nil
        guard let file = files.removeValue(forKey:id) else { return }
        guard active,let root = web?.window?.rootViewController,sharing == nil else { remove(file); return }
        var presenter = root
        while let next = presenter.presentedViewController { presenter = next }
        let sheet = UIActivityViewController(activityItems:[file],applicationActivities:nil)
        sheet.popoverPresentationController?.sourceView = web
        sheet.popoverPresentationController?.sourceRect = CGRect(x:(web?.bounds.midX ?? 0),y:40,width:1,height:1)
        sheet.completionWithItemsHandler = { [weak self] _,_,_,_ in
            Task { @MainActor in self?.remove(file); self?.sharing = nil }
        }
        sharing = sheet; presenter.present(sheet,animated:true)
    }
    func download(_ download:WKDownload,didFailWithError error:Error,resumeData:Data?) {
        let id = ObjectIdentifier(download); pending[id] = nil
        if let file = files.removeValue(forKey:id) { remove(file) }
        guard active,let root = web?.window?.rootViewController else { return }
        var presenter = root
        while let next = presenter.presentedViewController { presenter = next }
        guard !(presenter is UIAlertController),sharing == nil else { return }
        let alert = UIAlertController(title:"Download unavailable",message:"The export could not finish. No download was retried. You can try again from the server tool.",preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"OK",style:.default)); presenter.present(alert,animated:true)
    }
    private func remove(_ file:URL) {
        let directory = file.deletingLastPathComponent()
        guard directories.remove(directory) != nil else { return }
        try? FileManager.default.removeItem(at:directory)
    }
}
