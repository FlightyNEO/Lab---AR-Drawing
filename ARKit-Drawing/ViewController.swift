import ARKit

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    
    let configuration = ARWorldTrackingConfiguration()
    
    /// Mimimim distance between nearby points (in 2D coordinates)
    let touchDistanceThreshold = CGFloat(80)
    
    /// Coordinates of last placed point
    var lastObjectPlacedLocation: CGPoint?
    
    /// Node selected by user
    var selectedNode: SCNNode?
    
    /// Nodes placed by the user
    var placedNodes = [SCNNode]()
    
    /// Visualization planes placed when detecting planes
    var planeNodes = [SCNNode]()
    
    /// Defines whether plane visualisation is shown
    var showPlaneOverlay = false {
        didSet {
            for node in planeNodes {
                node.isHidden = !showPlaneOverlay
            }
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
    
    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
            showPlaneOverlay = false
        case 1:
            objectMode = .plane
            showPlaneOverlay = true
        case 2:
            objectMode = .image
            showPlaneOverlay = false
        default:
            break
        }
        
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
        
        guard !planeNodes.isEmpty else {
            dismiss(animated: true)
            return
        }
        
        planeNodes.removeLast().removeFromParentNode()
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
        
        switch objectMode {
        case .freeform:
            addNodeInFron(node)
        case .plane:
            let location = touch.location(in: sceneView)
            addNode(node, to: location)
        case .image: break
            
        }
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        func distanceBetweenLocations(_ locations: [CGPoint]) -> CGFloat {
            guard locations.count >= 2 else { return CGFloat() }
            
            let deltaX = locations.last!.x - locations.first!.x
            let deltaY = locations.last!.y - locations.first!.y
            
            return sqrt(deltaX * deltaX + deltaY * deltaY)
        }
        
        guard
            let touch = touches.first,
            let node = selectedNode,
            let lastLocation = lastObjectPlacedLocation else { return }
        
        
        let newLocation = touch.location(in: sceneView)
        let distance = distanceBetweenLocations([newLocation, lastLocation])
        
        guard distance >= touchDistanceThreshold else { return }
        
        if case .plane = objectMode {
            
            addNode(node, to: newLocation)
            
        }
        
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        lastObjectPlacedLocation = nil
    }
    
}

// MARK: - Placement methods
extension ViewController {
    
    /// Adds a node to parent node
    ///
    /// - Parameters:
    ///   - node: Node which will to be added
    ///   - parentNode: Parent node to which the node to be added
    ///   - isFloor: Parent node to which the node to be added
    private func addNode(_ node: SCNNode, to parentNode: SCNNode, isFloor: Bool = false) {
        
        let cloneNode = isFloor ? node : node.clone()
        
        parentNode.addChildNode(cloneNode)
        
        isFloor ? planeNodes.append(cloneNode) : placedNodes.append(cloneNode)
        
    }
    
    /// Places object defined by node at 20 cm before the camera
    ///
    /// - Parameter node: SCNNode to place in scene
    private func addNodeInFron(_ node: SCNNode) {
        
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.2
        
        node.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
        
        addNodeToSceneRoot(node)
    }
    
    private func addNode(_ node: SCNNode, to location: CGPoint) {
        
        guard let result = sceneView.hitTest(location, types: [.existingPlaneUsingGeometry]).first else { return }
        
        var translation = matrix_identity_float4x4
        translation.columns.3.y = node.boundingBox.min.y >= 0 ? node.boundingBox.min.y : node.boundingBox.max.y
        node.simdTransform = matrix_multiply(result.worldTransform, translation)
        
        addNodeToSceneRoot(node)
        lastObjectPlacedLocation = location
    }
    
    /// Adds an object adds an clone object defined by node to scene root
    ///
    /// - Parameter node: SCNNode wich will be added
    fileprivate func addNodeToSceneRoot(_ node: SCNNode) {
        
        let rootNode = sceneView.scene.rootNode
        addNode(node, to: rootNode)
    }
    
    /// Plane node AR anchor has been added to the scene
    ///
    /// - Parameters:
    ///   - node: Node which was added.
    ///   - anchor: AR plane anchor which defines the plane found.
    private func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        
        let size = CGSize(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        let placementArea = createPlacementArea(size: size)
        
        placementArea.isHidden = !showPlaneOverlay
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
    
    func createPlacementArea(size: CGSize) -> SCNNode {
        
        let placementAreaNode = SCNNode(geometry: SCNPlane(width: size.width, height: size.height))
        placementAreaNode.geometry?.firstMaterial?.diffuse.contents = #colorLiteral(red: 0.060786888, green: 0.223592639, blue: 0.8447286487, alpha: 0.5)
        placementAreaNode.eulerAngles.x = Float(-90.radians)
        placementAreaNode.name = "placementArea"
        
        return placementAreaNode
    }
    
    func updatePlacementArea(_ node: SCNNode, planeAnchor: ARPlaneAnchor) {
        
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
