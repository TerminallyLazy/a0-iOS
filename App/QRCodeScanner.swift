import SwiftUI
import VisionKit

/// Camera images stay in VisionKit. Only the first QR payload leaves this view.
struct QRCodeScanner: UIViewControllerRepresentable {
    let received: (String) -> Void
    let failed: () -> Void
    func makeUIViewController(context: Context) -> QRScannerController {
        QRScannerController(received:received,failed:failed)
    }
    func updateUIViewController(_ controller: QRScannerController, context: Context) {}
    static func dismantleUIViewController(_ controller: QRScannerController, coordinator: ()) { controller.stop() }
}

@MainActor final class QRScannerController: UIViewController, DataScannerViewControllerDelegate {
    private let scanner = DataScannerViewController(recognizedDataTypes:[.barcode(symbologies:[.qr])],
        qualityLevel:.balanced, recognizesMultipleItems:false, isHighFrameRateTrackingEnabled:false,
        isPinchToZoomEnabled:true, isGuidanceEnabled:true, isHighlightingEnabled:true)
    private let received: (String) -> Void
    private let failed: () -> Void
    private var finished = false
    init(received: @escaping (String) -> Void, failed: @escaping () -> Void) {
        self.received = received; self.failed = failed
        super.init(nibName:nil,bundle:nil)
    }
    required init?(coder: NSCoder) { nil }
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(scanner)
        scanner.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanner.view)
        NSLayoutConstraint.activate([
            scanner.view.leadingAnchor.constraint(equalTo:view.leadingAnchor),
            scanner.view.trailingAnchor.constraint(equalTo:view.trailingAnchor),
            scanner.view.topAnchor.constraint(equalTo:view.topAnchor),
            scanner.view.bottomAnchor.constraint(equalTo:view.bottomAnchor)
        ])
        scanner.didMove(toParent:self); scanner.delegate = self
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !finished else { return }
        do { try scanner.startScanning() }
        catch { unavailable() }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated); stop()
    }
    func stop() { finished = true; scanner.stopScanning(); scanner.delegate = nil }
    private func receive(_ items: [RecognizedItem]) {
        guard !finished else { return }
        for item in items {
            if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                stop(); received(payload); return
            }
        }
    }
    private func unavailable() {
        guard !finished else { return }
        stop(); failed()
    }
    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) { receive(addedItems) }
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) { receive([item]) }
    func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) { unavailable() }
}
