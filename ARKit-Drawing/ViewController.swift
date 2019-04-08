import ARKit

class ViewController: UIViewController {
    
    // MARK: IBOutlets
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!
    @IBOutlet weak var planeVizualizationSwitch: UISwitch!
    
    // MARK: - Properties
    
    let configuration = ARWorldTrackingConfiguration()
    
    /// Mimimim distance between nearby nodes (in 3D coordinates)
    let minDistanceBetweenVirtualObjects = Float(0.05)
    
    /// Node selected by user
    var selectedNode: SCNNode?
    
    /// Nodes placed by the user
    var placedNodes = [SCNNode]() {
        didSet {
            DispatchQueue.main.async {
                self.undoButton.isEnabled = self.placedNodes.isEmpty ? false : true
            }
        }
    }
    
    /// Nodes placed by the user remove from scene
    var removedPlacedNodes = [SCNNode]() {
        didSet {
            DispatchQueue.main.async {
                self.redoButton.isEnabled = self.removedPlacedNodes.isEmpty ? false : true
            }
        }
    }
    
    /// Visualization planes placed when detecting planes
    var planeNodes = [SCNNode]()
    
    /// Defines whether plane visualisation is shown
    var showPlaneOverlay = false {
        didSet {
            for node in planeNodes {
                if case .plane = objectMode {
                    node.isHidden = !showPlaneOverlay
                } else {
                    node.isHidden = true
                }
            }
//            if case .plane = objectMode {
//                for node in planeNodes {
//                    node.isHidden = !showPlaneOverlay
//                }
//            } else {
//                for node in planeNodes {
//                    node.isHidden = true
//                }
//            }
        }
    }
    
    var objectMode: ObjectPlacementMode = .freeform {
        didSet {
            reloadConfiguration(removeAnchors: false)
        }
    }
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    // MARK: - Life cicle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        reloadConfiguration(removeAnchors: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }

    
}

// MARK: - Actions
extension ViewController {
    
    @IBAction func resetScene(_ sender: UIButton) {
        self.reloadConfiguration()
    }
    
    @IBAction func togglePlaneVisualization(_ sender: UISwitch) {
        self.showPlaneOverlay = sender.isOn
    }
    
    @IBAction func undoLastObjectFromScene() {
        
        guard !placedNodes.isEmpty else { return }
        
        let node = placedNodes.removeLast()
        
        node.removeFromParentNode()
        removedPlacedNodes.append(node)
    }
    
    @IBAction func redoLasObjectToScene() {
        
        guard !removedPlacedNodes.isEmpty else { return }
        
        addNodeToSceneRoot(removedPlacedNodes.removeLast(), clearTheRemovedNodesList: false)
    }
    
    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
        case 1:
            objectMode = .plane
        case 2:
            objectMode = .image
        default:
            break
        }
        
        showPlaneOverlay = planeVizualizationSwitch.isOn
    }
    
}

// MARK: - Navigation
extension ViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
    
}

// MARK: - Options view controller delegate
extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        dismiss(animated: true) {
            self.selectedNode = node
        }
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true) {
            self.showPlaneOverlay.toggle()
        }
    }
    
    func undoLastObject() {
        
        guard !placedNodes.isEmpty else {
            dismiss(animated: true)
            return
        }
        placedNodes.removeLast().removeFromParentNode()
    }
    
    func resetScene() {
        dismiss(animated: true) {
            self.reloadConfiguration()
        }
    }
    
}

// MARK: - Touches
extension ViewController {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard
            let touch = touches.first,
            let node = selectedNode else { return }
        
        let location = touch.location(in: sceneView)
        
        switch objectMode {
        case .plane, .freeform: tryAddNode(node, to: location)
        default: break
        }
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard
            let touch = touches.first,
            let node = selectedNode else { return }
        
        let location = touch.location(in: sceneView)
        
        switch objectMode {
        case .plane, .freeform: tryAddNode(node, to: location)
        default: break
        }
        
    }
    
}

// MARK: - Placement methods
extension ViewController {
    
    // MARK: ...checking
    private func checkDistance(from node: SCNNode, to nodes: [SCNNode]) -> Bool {
        
        for secondNode in nodes {
            guard checkDistanceUsingBoxBetweenNodes([node, secondNode]) else {
                return false
            }
        }
        
        return true
    }
    
    private func checkDistanceUsingBoxBetweenNodes(_ nodes: [SCNNode]) -> Bool {
        
        guard
            let firstNode = nodes.first,
            let secontNode = nodes.last else { return false }
        
        let maxSizeFirstNode = firstNode.maxSide
        let maxSizeSecondNode = secontNode.maxSide
        
        var distance = firstNode.worldPosition.distanceTo(secontNode.worldPosition)
        distance -= maxSizeFirstNode / 2
        distance -= maxSizeSecondNode / 2
        
        return distance >= minDistanceBetweenVirtualObjects
        
    }
    
    private func checkDistanceUsingSphereBetweenNodes(_ nodes: [SCNNode]) -> Bool {
        
        guard
            let firstNode = nodes.first,
            let secontNode = nodes.last else { return false }
        
        let firstSphere = firstNode.geometry?.boundingSphere
        let secondSphere = secontNode.geometry?.boundingSphere
        
        var distance = firstNode.worldPosition.distanceTo(secontNode.worldPosition)
        distance -= firstSphere?.radius ?? 0
        distance -= secondSphere?.radius ?? 0
        
        return distance >= minDistanceBetweenVirtualObjects
        
    }
    
    // MARK: ...calculating
    private func calculateTransformForPlanePosition(for node: SCNNode, use location: CGPoint) -> simd_float4x4? {
        
        guard let result = sceneView.hitTest(location, types: .existingPlaneUsingGeometry).first else { return nil }
        
        var translation = matrix_identity_float4x4
        translation.columns.3.y = node.boundingBox.min.y >= 0 ? node.boundingBox.min.y : node.boundingBox.max.y
        
        return matrix_multiply(result.worldTransform, translation)
        
    }
        
    private func calculateTransformForFrontPosition(for node: SCNNode, use location: CGPoint) -> simd_float4x4? {
        
        guard let currentFrame = sceneView.session.currentFrame else { return nil }
        
        let center = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        let translateX = Float((location.x - center.x) / 3000)
        let translateY = Float((location.y - center.y) / 3000)
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -max(node.depth * 3, 0.2)
        translation.columns.3.x = translateY
        translation.columns.3.y = translateX
        
        return matrix_multiply(currentFrame.camera.transform, translation)
    }
    
    // MARK: ...adding
    
    private func tryAddNode(_ node: SCNNode, to location: CGPoint) {
        
        var transform: simd_float4x4?
        
        switch objectMode {
        case .freeform:
            transform = calculateTransformForFrontPosition(for: node, use: location)
        case .plane:
            transform = calculateTransformForPlanePosition(for: node, use: location)
        default:
            break
        }
        
        guard transform != nil else { return }
        
        node.simdWorldTransform = transform!
        
        // Check minimum distance
        guard checkDistance(from: node, to: placedNodes) else { return }
        
        // Add node to scene root
        addNodeToSceneRoot(node)
    }
    
    /// Adds a node to parent node
    ///
    /// - Parameters:
    ///   - node: Node which will to be added
    ///   - parentNode: Parent node to which the node to be added
    ///   - isFloor: Parent node to which the node to be added
    private func addNode(_ node: SCNNode, to parentNode: SCNNode, isFloor: Bool = false, clearTheRemovedNodesList: Bool = true) {
        
        let cloneNode = isFloor ? node : node.clone()
        
        parentNode.addChildNode(cloneNode)
        
        isFloor ? planeNodes.append(cloneNode) : placedNodes.append(cloneNode)
        
        clearTheRemovedNodesList ? removedPlacedNodes.removeAll() : nil
        
    }
    
    /// Adds an object adds an clone object defined by node to scene root
    ///
    /// - Parameter node: SCNNode wich will be added
    private func addNodeToSceneRoot(_ node: SCNNode, clearTheRemovedNodesList: Bool = true) {
        
        let rootNode = sceneView.scene.rootNode
        addNode(node, to: rootNode, clearTheRemovedNodesList: clearTheRemovedNodesList)
    }
    
    /// Plane node AR anchor has been added to the scene
    ///
    /// - Parameters:
    ///   - node: Node which was added.
    ///   - anchor: AR plane anchor which defines the plane found.
    private func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        
        let size = CGSize(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        let placementArea = createPlacementArea(size: size)
        
        if case .plane = objectMode {
            for node in planeNodes {
                node.isHidden = !showPlaneOverlay
            }
        } else {
            for node in planeNodes {
                node.isHidden = true
            }
        }
        
        if case .plane = objectMode {
            placementArea.isHidden = !showPlaneOverlay
        } else {
            placementArea.isHidden = true
        }
        
        addNode(placementArea, to: node, isFloor: true)
    }
    
    /// Image node AR anchor has been added to the scene
    ///
    /// - Parameters:
    ///   - node: Node which was added.
    ///   - anchor: AR plane anchor which defines the image found.
    private func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor) {
        
        guard let selectedNode = selectedNode else { return }
        
        addNode(selectedNode, to: node)
    }
    
    private func createPlacementArea(size: CGSize) -> SCNNode {
        
        let placementAreaNode = SCNNode(geometry: SCNPlane(width: size.width, height: size.height))
        placementAreaNode.geometry?.firstMaterial?.diffuse.contents = #colorLiteral(red: 0.060786888, green: 0.223592639, blue: 0.8447286487, alpha: 0.5)
        placementAreaNode.eulerAngles.x = Float(-90.radians)
        placementAreaNode.name = "placementArea"
        
        return placementAreaNode
    }
    
    // MARK: ...updating
    
    private func updatePlacementArea(_ node: SCNNode, planeAnchor: ARPlaneAnchor) {
        
        let size = CGSize(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let center = planeAnchor.center
        
        node.position = SCNVector3(center.x, 0, center.z)
        
        (node.geometry as? SCNPlane)?.width = size.width
        (node.geometry as? SCNPlane)?.height = size.height
        
    }
    
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        if let planeAnchor = anchor as? ARPlaneAnchor {
            
            nodeAdded(node, for: planeAnchor)
            
        } else if let imageAnchor = anchor as? ARImageAnchor {
            
            nodeAdded(node, for: imageAnchor)
            
        }
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        guard
            let planeAnchor = anchor as? ARPlaneAnchor,
            let placementArea = node.childNode(withName: "placementArea", recursively: false)
            else { return }
        
        updatePlacementArea(placementArea, planeAnchor: planeAnchor)
        
    }
    
}

// MARK: - Configuration methods
extension ViewController {
    
    private func reloadConfiguration(removeAnchors: Bool = true) {
        
        configuration.planeDetection = [.horizontal, .vertical]
        
        var options: ARSession.RunOptions = []
        
        if removeAnchors {
            
            options.insert(.removeExistingAnchors)
            
            planeNodes.removeAll()
            
            placedNodes.forEach { $0.removeFromParentNode() }
            placedNodes.removeAll()
            
        }
        
        if case .image = objectMode {
            let detectionImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil)
            configuration.detectionImages = detectionImages
        } else {
            configuration.detectionImages = nil
        }
        
        sceneView.session.run(configuration, options: options)
        
    }
    
}
