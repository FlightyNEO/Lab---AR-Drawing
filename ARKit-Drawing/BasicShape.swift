import UIKit

enum ShapeOption: String, RawRepresentable {
    case addShape = "Select Basic Shape"
    case addScene = "Select Scene File"
    case togglePlane = "Enable/Disable Plane Visualization"
    case undoLastShape = "Undo Last Shape"
    case resetScene = "Reset Scene"
}

enum Shape: String, CaseIterable {
    case box = "Box", sphere = "Sphere", cylinder = "Cylinder", cone = "Cone", torus = "Torus", pyramid = "Pyramid"
}

enum Size: String, CaseIterable {
    case small = "Small", medium = "Medium", large = "Large", extraLarge = "Extra Large"
}
