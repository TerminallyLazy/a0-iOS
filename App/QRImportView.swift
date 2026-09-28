import SwiftUI
import AVFoundation
import VisionKit
import A0Core

/// This sheet keeps untrusted input separate from the active connection form.
struct QRImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let model: SpikeModel
    @State private var flow = QRImportSession()
    @State private var payload = ""
    @State private var cameraID: UUID?
    @State private var permissionTask: Task<Void, Never>?
    @FocusState private var addressFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let id = cameraID {
                    QRCodeScanner { value in
                        guard cameraID == id, flow.scanID == id else { return }
                        cameraID = nil
                        flow.receive(value,from:id)
                    } failed: {
                        guard cameraID == id, flow.scanID == id else { return }
                        cameraID = nil
                        flow.failCamera(.cameraUnavailable,from:id)
                    }
                    .overlay(alignment:.bottom) {
                        Button("Enter address instead") { stopCamera() }
                            .buttonStyle(.borderedProminent).padding()
                    }
                    .accessibilityLabel("Point the camera at your server QR code")
                } else {
                    Form {
                        if let destination = flow.destination {
                            Section("Check the destination") {
                                Text(destination.origin.header)
                                    .font(.title3.weight(.semibold))
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal:false,vertical:true)
                                    .accessibilityIdentifier("qrDestination")
                                Text("Compare this address with the one shown by your Agent Zero server. You'll enter credentials on the next screen.")
                                Button("Use this server") {
                                    guard let destination = flow.confirm() else { return }
                                    model.useQRDestination(destination)
                                    dismiss()
                                }.accessibilityIdentifier("confirmQR")
                                Button("Scan or enter another address") { flow.cancel() }
                            }
                        } else {
                            Section {
                                Text("Open the tunnel QR code on your Agent Zero server, then scan it here.")
                                Button("Open camera", systemImage:"qrcode.viewfinder") { startCamera() }
                                    .disabled(flow.scanID != nil)
                                if flow.scanID != nil { ProgressView("Waiting for camera access") }
                            }
                            if let issue = flow.issue {
                                Section {
                                    Label(issue.message,systemImage:"exclamationmark.circle")
                                        .accessibilityIdentifier("qrIssue")
                                    if issue == .cameraDenied, let settings = URL(string:UIApplication.openSettingsURLString) {
                                        Link("Open Settings",destination:settings)
                                    }
                                }
                            }
                            Section {
                                TextField("HTTPS server address",text:$payload)
                                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .focused($addressFocused).accessibilityIdentifier("qrPayload")
                                    .submitLabel(.go).onSubmit { reviewAddress() }
                                Button("Review address") { reviewAddress() }
                                    .disabled(payload.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                            } header: { Text("Or enter an address") } footer: {
                                Text("Scanning or reviewing an address does not connect or save a server.")
                            }
                        }
                    }
                }
            }
            .navigationTitle(flow.destination == nil ? "Add server" : "Review server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) {
                    Button("Cancel") { stopCamera(); dismiss() }.accessibilityIdentifier("Cancel import")
                }
            }
            .onDisappear { stopCamera() }
            .onChange(of:scenePhase) { _,phase in
                if phase == .background { stopCamera() }
            }
        }
    }
    private func reviewAddress() {
        permissionTask?.cancel(); cameraID = nil; addressFocused = false
        flow.review(payload); payload = ""
    }
    private func stopCamera() {
        permissionTask?.cancel(); permissionTask = nil
        cameraID = nil; payload = ""; flow.cancel()
    }
    private func startCamera() {
        addressFocused = false; payload = ""
        let id = flow.beginScan()
        permissionTask = Task { @MainActor in
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--profile-ui-test") {
                if args.contains("--qr-camera-denied") { flow.failCamera(.cameraDenied,from:id); return }
                if args.contains("--qr-camera-unavailable") { flow.failCamera(.cameraUnavailable,from:id); return }
            }
            #endif
            guard DataScannerViewController.isSupported else { flow.failCamera(.cameraUnavailable,from:id); return }
            let granted: Bool
            switch AVCaptureDevice.authorizationStatus(for:.video) {
            case .authorized: granted = true
            case .notDetermined: granted = await AVCaptureDevice.requestAccess(for:.video)
            default: granted = false
            }
            guard !Task.isCancelled, flow.scanID == id else { return }
            guard granted else { flow.failCamera(.cameraDenied,from:id); return }
            guard DataScannerViewController.isAvailable else { flow.failCamera(.cameraUnavailable,from:id); return }
            cameraID = id
        }
    }
}
