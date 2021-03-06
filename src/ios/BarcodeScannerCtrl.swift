import UIKit
import AVFoundation
import Vision

@available(iOS 11.0, *)
class BarcodeScannerCtrl: UIViewController, FrameProcessorDelegate {

    var scannedCodes: [String] = [String]()
    var scannedQRCodes: [String] = [String]()
    @IBOutlet var previewView: UIView!
    var frameProcessor: FrameProcessor!
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    var pluginContext: CDVPlugin!
    var command: CDVInvokedUrlCommand!
    var mode: String = "BARCODE"

    private lazy var drawLayer: CAShapeLayer = {
        let drawLayer = CAShapeLayer()
        self.view.layer.addSublayer(drawLayer)
        drawLayer.frame = self.view.bounds
        drawLayer.strokeColor = UIColor.blue.cgColor
        drawLayer.lineWidth = 2
        drawLayer.fillColor = UIColor(red: 255, green: 165, blue: 0, alpha: 0.6).cgColor
        drawLayer.lineJoin = kCALineJoinRound
        drawLayer.fillColor = UIColor.clear.cgColor
        return drawLayer
    }()


    func onBarcodesRead(barcodes: [VNBarcodeObservation]) {
        DispatchQueue.main.async {
             let path = CGMutablePath()
             for barcode in barcodes {
                self.drawRect(path, barcode: barcode)


                if ((barcode.barcodeDescriptor as? CIQRCodeDescriptor) != nil) && self.mode == "QR" {
                    guard let payload = barcode.payloadStringValue else { continue }
                    if !self.scannedCodes.contains(payload) {
                        self.scannedCodes.append(payload)
                    }
                }
                if ((barcode.barcodeDescriptor as? CIQRCodeDescriptor) == nil) && self.mode == "BARCODE" {
                    guard let payload = barcode.payloadStringValue else { continue }
                    if !self.scannedCodes.contains(payload) {
                        self.scannedCodes.append(payload)
                    }
                }

            }
            self.drawLayer.path = path
        }
    }


    private func drawRect(_ path: CGMutablePath, barcode: VNBarcodeObservation) {
        let bottomLeft = self.convert(point: barcode.bottomLeft)
        let topLeft = self.convert(point: barcode.topLeft)
        let topRight = self.convert(point: barcode.topRight)
        let bottomRight = self.convert(point: barcode.bottomRight)
        let sequence: [CGPoint] = [topRight, bottomRight, bottomLeft, topLeft]
        if self.mode == "QR" && barcode.barcodeDescriptor as? CIQRCodeDescriptor != nil {
            path.move(to: topLeft)
            for seq in sequence {
                path.addLine(to: seq)
            }
        }
        if self.mode == "BARCODE" && barcode.barcodeDescriptor as? CIQRCodeDescriptor == nil {
            let rect = self.adjustBoundsToScreen(barcode: barcode)
            path.addRect(rect)
        }
    }

    private func convert(point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x * view.bounds.size.width,
                       y: (1 - point.y) * view.bounds.size.height)
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.layer.drawsAsynchronously = true
        initFrameProcessor()
        createButton()
    }


    private func initFrameProcessor() {
        frameProcessor = FrameProcessor()
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: frameProcessor.captureSession)
        cameraPreviewLayer!.videoGravity = .resizeAspectFill
        cameraPreviewLayer!.connection?.videoOrientation = .portrait
        cameraPreviewLayer?.frame = view.frame
        frameProcessor.delegate = self
        self.view.layer.insertSublayer(cameraPreviewLayer!, at:0)
    }

    func adjustBoundsToScreen(barcode: VNBarcodeObservation) -> CGRect {
        let xCord = barcode.boundingBox.origin.x * self.previewView.frame.size.width
        var yCord = (1 - barcode.boundingBox.origin.y) * self.previewView.frame.size.height
        let width = barcode.boundingBox.size.width * self.previewView.frame.size.width
        var height = -1 * barcode.boundingBox.size.height * self.previewView.frame.size.height
        yCord += height
        height *= -1

        return CGRect(x: xCord, y: yCord, width: width, height: height)
    }


    func createButton() {
        let scanResults = UIButton(frame: CGRect(x: (view.frame.width / 2) - 75, y: view.frame.height - 95, width: 150, height: 50))
        scanResults.layer.cornerRadius = 8.0
        scanResults.backgroundColor = UIColor.systemBlue
        scanResults.setTitle("Show Scanned", for: .normal)
        scanResults.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        self.view.addSubview(scanResults)

        let cancel = UIButton(frame: CGRect(x: (view.frame.width * 3 / 4) - 75, y: view.frame.height - 95, width: 150, height: 50))
        cancel.layer.cornerRadius = 8.0
        cancel.backgroundColor = UIColor.systemBlue
        cancel.setTitle("Cancel", for: .normal)
        cancel.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        self.view.addSubview(cancel)
    }

    @objc func buttonAction() {
        let scannedCodesCtrl: ScannedCodesOverview = ScannedCodesOverview()
        scannedCodesCtrl.scannedCodes = scannedCodes
        scannedCodesCtrl.pluginContext = pluginContext
        scannedCodesCtrl.command = command
        self.present(scannedCodesCtrl, animated: true)
    }

    @objc func cancelAction () {
        let result = CDVPluginResult(status: CDVCommandStatus_OK)
        pluginContext.commandDelegate!.send(result, callbackId: command.callbackId)
        pluginContext.viewController.dismiss(animated: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.frameProcessor.close()
        self.dismiss(animated: animated)
        self.pluginContext.viewController.dismiss(animated: true)
    }

}
