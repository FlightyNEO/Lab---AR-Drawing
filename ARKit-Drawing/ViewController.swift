import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    
    let configuration = ARWorldTrackingConfiguration()
    
    /// Node selected by user
    var selectedNode: SCNNode?
    
    /// Nodes placed by the user
    var placedNodes = [SCNNode]()
    
    /// Visualization planes placed when detecting planes
    var planeNodes = [SCNNode]()
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    var objectMode: ObjectPlacementMode = .freeform {
        didSet {
            reloadConfiguration()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        reloadConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
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
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
}

extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        dismiss(animated: true, completion: nil)
        
        selectedNode = node
        
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
    }
    
    func undoLastObject() {
        
    }
    
    func resetScene() {
        dismiss(animated: true, completion: nil)
    }
    
}

// MARK: - Touches
extension ViewController {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        guard let node = selectedNode else { return }
        
        switch objectMode {
        case .freeform:
            addNodeInFron(node)
        case .plane:
            let location = touch.location(in: sceneView)
            addNodeToPlace(node, to: location)
        case .image: break
            
        }
        
    }
    
}

// MARK: - Placement methods
extension ViewController {
    
    /// Adds a node to parent node
    ///
    /// - Parameters:
    ///   - node: Node which will to be added
    ///   - parentNode: Parent node to which the node to be added
    private func addNode(_ node: SCNNode, to parentNode: SCNNode) {
        
        let cloneNode = node.clone()
        
        parentNode.addChildNode(cloneNode)
        placedNodes.append(cloneNode)
        
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
    
    private func addNodeToPlace(_ node: SCNNode, to location: CGPoint) {
        
        guard let result = sceneView.hitTest(location, types: [.existingPlaneUsingGeometry]).first else { return }
        
        var translation = matrix_identity_float4x4
        translation.columns.3.y = node.boundingBox.min.y >= 0 ? node.boundingBox.min.y : node.boundingBox.max.y
        node.simdTransform = matrix_multiply(result.worldTransform, translation)
        
        addNodeToSceneRoot(node)
        
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
    
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    
    func addPlacementArea(to parentNode: SCNNode, withSize size: CGSize) {
        
//        let placementAreaNode = SCNNode(geometry: SCNPlane(width: size.width, height: size.height))
//        placementAreaNode.geometry?.firstMaterial?.diffuse.contents = #colorLiteral(red: 0.060786888, green: 0.223592639, blue: 0.8447286487, alpha: 0.5)
//        placementAreaNode.eulerAngles.x = Float(-90.radians)
//        placementAreaNode.name = "placementArea"
//
//        addNode(placementAreaNode, to: parentNode)
        
    }
    
    func updatePlacementArea(_ node: SCNNode, withSize size: CGSize) {
        
        (node.geometry as? SCNPlane)?.width = size.width
        (node.geometry as? SCNPlane)?.height = size.height
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        if let planeAnchor = anchor as? ARPlaneAnchor {
            
            let size = CGSize(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
            
            addPlacementArea(to: node, withSize: size)
            
        } else if let imageAnchor = anchor as? ARImageAnchor {
            
            nodeAdded(node, for: imageAnchor)
            
        }
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        if let planeAnchor = anchor as? ARPlaneAnchor {
            
            let size = CGSize(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
            
            guard let placementArea = node.childNode(withName: "placementArea", recursively: false) else { return }
            updatePlacementArea(placementArea, withSize: size)
            
            nodeAdded(placementArea, for: planeAnchor)
            
        }
        
    }
    
}

// MARK: - Configuration methods
extension ViewController {
    
    private func reloadConfiguration() {
        
        let detectionImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil)
        
        switch objectMode {
        case .freeform:
            configuration.detectionImages = nil
        case .plane:
            configuration.planeDetection = .horizontal
            configuration.detectionImages = nil
        case .image:
            configuration.detectionImages = detectionImages
        }
        
        sceneView.session.run(configuration)
        
    }
    
}
