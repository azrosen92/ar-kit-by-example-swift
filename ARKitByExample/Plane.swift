//
//  Plane.swift
//  ARKitByExample
//
//  Created by Aaron Rosen on 8/1/17.
//  Copyright © 2017 Aaron Rosen. All rights reserved.
//

import Foundation
import SceneKit
import ARKit

class Plane: SCNNode {
    let anchor: ARPlaneAnchor
    let planeGeometry: SCNPlane

    init(with anchor: ARPlaneAnchor) {
        self.anchor = anchor
        // Create the 3D plane geometry with the dimensions reported
        // by ARKit in the ARPlaneAnchor instance
        self.planeGeometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))

        // Add a tron style grid texture to plane.
        let material = SCNMaterial()
        let image = UIImage(named: "tron-grid")
        material.diffuse.contents = image
        self.planeGeometry.materials = [material]

        let planeNode = SCNNode(geometry: self.planeGeometry)
        // Move the plane to the position reported by ARKit
        planeNode.position = SCNVector3Make(anchor.center.x, anchor.extent.y, anchor.center.z)
        // Give the plane a physics body so that items we add to the scene interact with it
        planeNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: self.planeGeometry, options: nil))
        // Planes in SceneKit are vertical by default so we need to rotate
        // 90 degrees to match planes in ARKit
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi/2.0, 1.0, 0.0, 0.0)

        super.init()

        self.setTextureScale()
        self.addChildNode(planeNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTextureScale() {
        let width = Float(self.planeGeometry.width)
        let height = Float(self.planeGeometry.height)

        // As the width/height of the plane updates, we want our tron grid material to
        // cover the entire plane, repeating the texture over and over. Also if the
        // grid is less than 1 unit, we don't want to squash the texture to fit, so
        // scaling updates the texture co-ordinates to crop the texture in that case
        if let material = self.planeGeometry.materials.first {
            material.diffuse.contentsTransform = SCNMatrix4MakeScale(width, height, 1)
            material.diffuse.wrapT = .repeat
            material.diffuse.wrapS = .repeat
        }
    }

    func update(_ anchor: ARPlaneAnchor) {
        // As the user moves around the extend and location of the plane
        // may be updated. We need to update our 3D geometry to match the
        // new parameters of the plane.
        self.planeGeometry.width = CGFloat(anchor.extent.x)
        self.planeGeometry.height = CGFloat(anchor.extent.z)

        // When the plane is first created it's center is 0,0,0 and
        // the nodes transform contains the translation parameters.
        // As the plane is updated the planes translation remains the
        // same but it's center is updated so we need to update the 3D
        // geometry position
        self.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z)
        self.setTextureScale()
    }

    func hide() {
        let transparentMaterial = SCNMaterial()
        transparentMaterial.diffuse.contents = UIColor(white: 1.0, alpha: 0.0)
        self.planeGeometry.materials = [transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial, transparentMaterial]

    }
}
