import UIKit
import QuickLook

protocol DocumentPreviewDelegate: AnyObject {
    func didSendDocument(fileURL: URL)
}

class DocumentPreviewViewController: UIViewController, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    public var completion: ((URL) -> Void)?

    var fileURL: URL?
    weak var delegate: DocumentPreviewDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Document Preview"
        
        // QuickLook Önizleyiciyi Aç
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self
        addChild(previewController)
        previewController.view.frame = view.bounds
        view.addSubview(previewController.view)
        previewController.didMove(toParent: self)
        
        // Gönder Butonu
        let sendButton = UIButton(type: .system)
        sendButton.setTitle("Gönder", for: .normal)
        sendButton.addTarget(self, action: #selector(sendDocument), for: .touchUpInside)
        sendButton.frame = CGRect(x: 20, y: view.frame.height - 60, width: view.frame.width - 40, height: 40)
        sendButton.backgroundColor = .systemBlue
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.layer.cornerRadius = 10
        view.addSubview(sendButton)
    }
    
    @objc func sendDocument() {
        guard let fileURL = fileURL else { return }
        completion?(fileURL)
        navigationController?.popViewController(animated: true)
    }

    // MARK: - QLPreviewController Data Source
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return fileURL != nil ? 1 : 0
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return fileURL! as QLPreviewItem
    }
}
