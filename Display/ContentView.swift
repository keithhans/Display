//
//  ViewController.swift
//  Display
//
//  Created by keith on 2025/3/10.
//

import UIKit
import Network

class ImageServer {
    private var listener: NWListener?
    private var dataBuffer: Data
    private var expectedLength: Int?
    
    init() {
        dataBuffer = Data()
        setupServer()
    }
    
    private func setupServer() {
        let parameters = NWParameters.tcp
        
        listener = try? NWListener(using: parameters, on: 8080)
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Server is ready on port 8080")
            case .failed(let error):
                print("Server failed with error: \(error)")
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.start(queue: .main)
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.receiveData(on: connection)
            case .failed(let error):
                print("Connection failed: \(error)")
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
    
    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("接收数据错误: \(error)")
                return
            }
            
            if let data = content {
                print("接收到数据大小: \(data.count) bytes")
                self.dataBuffer.append(data)
                
                // 如果是第一个数据包，尝试读取数据长度
                if self.expectedLength == nil && self.dataBuffer.count >= 4 {
                    self.expectedLength = Int(self.dataBuffer.prefix(4).withUnsafeBytes { bytes in
                        let value = bytes.load(as: UInt32.self)
                        return UInt32(bigEndian: value)
                    })
                    self.dataBuffer.removeFirst(4)
                    print("预期接收数据大小: \(self.expectedLength ?? 0) bytes")
                }
                
                // 检查是否接收完整
                if let expectedLength = self.expectedLength, self.dataBuffer.count >= expectedLength {
                    let imageData = self.dataBuffer.prefix(expectedLength)
                    if let image = UIImage(data: Data(imageData)) {
                        print("图片解码成功，尺寸: \(image.size)")
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .newImageReceived, object: image)
                        }
                        
                        // Send success response
                        let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"
                        connection.send(content: response.data(using: .utf8), completion: .idempotent)
                    } else {
                        print("图片解码失败，可能是不支持的格式或损坏的数据")
                        // Send error response
                        let response = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n"
                        connection.send(content: response.data(using: .utf8), completion: .idempotent)
                    }
                    
                    // 重置缓冲区
                    self.dataBuffer.removeAll()
                    self.expectedLength = nil
                    return
                }
            }
            
            if !isComplete && error == nil {
                self.receiveData(on: connection)
            }
        }
    }
}

extension Notification.Name {
    static let newImageReceived = Notification.Name("newImageReceived")
}

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var imageHistory: [UIImage] = []
    private let cellIdentifier = "ImageCell"
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .black
        view.isPagingEnabled = true
        view.showsHorizontalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let imageServer = ImageServer()

    
    private let waitingLabel: UILabel = {
        let label = UILabel()
        label.text = "等待接收图片..."
        label.font = .systemFont(ofSize: 24)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(handleNewImage),
                                             name: .newImageReceived,
                                             object: nil)
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        view.addSubview(collectionView)
        view.addSubview(waitingLabel)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            waitingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            waitingLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func handleNewImage(_ notification: Notification) {
        if let image = notification.object as? UIImage {
            imageHistory.append(image)
            collectionView.reloadData()
            collectionView.scrollToItem(at: IndexPath(item: imageHistory.count - 1, section: 0), at: .centeredHorizontally, animated: true)
            waitingLabel.isHidden = true
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageHistory.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath)
        
        // 移除之前的imageView（如果存在）
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let imageView = UIImageView(frame: cell.contentView.bounds)
        imageView.contentMode = .scaleAspectFit
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.image = imageHistory[indexPath.item]
        cell.contentView.addSubview(imageView)
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
}
