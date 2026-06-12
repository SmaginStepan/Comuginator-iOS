import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    let onResult: (String) -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult, onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        let onResult: (String) -> Void
        let onDismiss: () -> Void
        init(onResult: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
            self.onResult = onResult; self.onDismiss = onDismiss
        }
        func didFind(code: String) { onResult(code) }
        func didCancel() { onDismiss() }
    }
}

// MARK: - Delegate protocol

protocol ScannerViewControllerDelegate: AnyObject {
    func didFind(code: String)
    func didCancel()
}

// MARK: - View controller

final class ScannerViewController: UIViewController {
    weak var delegate: ScannerViewControllerDelegate?

    private let session = AVCaptureSession()
    /// All session operations MUST run on this queue — never on the main thread.
    private let sessionQueue = DispatchQueue(label: "com.comuginator.camera.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addCancelButton()
        requestPermissionAndConfigure()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    // MARK: Permission

    private func requestPermissionAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { self.configure() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.sessionQueue.async { self.configure() }
                } else {
                    DispatchQueue.main.async { self.delegate?.didCancel() }
                }
            }
        default:
            showPermissionDenied()
        }
    }

    // MARK: Setup (runs on sessionQueue)

    private func configure() {
        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }

        session.beginConfiguration()
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        session.commitConfiguration()

        // Add preview layer on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let layer = AVCaptureVideoPreviewLayer(session: self.session)
            layer.frame = self.view.bounds
            layer.videoGravity = .resizeAspectFill
            self.view.layer.insertSublayer(layer, at: 0)  // behind buttons
            self.previewLayer = layer
        }

        isConfigured = true
        session.startRunning()
    }

    // MARK: UI

    private func addCancelButton() {
        let btn = UIButton(type: .system)
        btn.setTitle("Cancel", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            btn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        btn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    private func showPermissionDenied() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let label = UILabel()
            label.text = "Camera access denied.\nEnable it in Settings."
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 32),
                label.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -32)
            ])
        }
    }

    @objc private func cancelTapped() { delegate?.didCancel() }
}

// MARK: - Metadata delegate (fires on main queue)

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput objects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let obj = objects.first as? AVMetadataMachineReadableCodeObject,
            let value = obj.stringValue
        else { return }

        // Stop session on its dedicated queue — never on main
        sessionQueue.async { self.session.stopRunning() }
        delegate?.didFind(code: value)
    }
}
