//
//  ViewController.swift
//  ARKitByExample
//
//  Created by Aaron Rosen on 8/1/17.
//  Copyright © 2017 Aaron Rosen. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    let CollisionCategoryCube = 1 << 1
    let CollisionCategoryBottom = 1 << 0

    @IBOutlet var sceneView: ARSCNView!

    // A dictionary of all the current planes being rendered in the scene
    var planes = [UUID: Plane]()
    var boxes = [SCNNode]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupScene()
        self.setupRecognizers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - Setup functions

    func setupScene() {
        // Setup the ARSCNViewDelegate - this gives us callbacks to handle new
        // geometry creation
        self.sceneView.delegate = self
        // Show statistics such as fps and timing information
        self.sceneView.showsStatistics = true
        self.sceneView.autoenablesDefaultLighting = true
        // Turn on debug options to show the world origin and also render all
        // of the feature points ARKit is tracking
        self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]

        let scene = SCNScene()
        self.sceneView.scene = scene
    }

    func setupSession() {
        // Create a session configuration
        let configuration = ARWorldTrackingSessionConfiguration()
        configuration.planeDetection = .horizontal
        // Run the view's session
        sceneView.session.run(configuration)
    }

    func setupRecognizers() {
        // Single tap will insert a new piece of geometry into the scene
        let tapGetsureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapFrom(_:)))
        tapGetsureRecognizer.numberOfTapsRequired = 1
        self.sceneView.addGestureRecognizer(tapGetsureRecognizer)

        // Press and hold will cause an explosion causing geometry in the local vicinity of the explosion to move
        let explosionGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleHoldFrom(_:)))
        explosionGestureRecognizer.minimumPressDuration = 0.5
        self.sceneView.addGestureRecognizer(explosionGestureRecognizer)

        let hidePlanesGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleHidePlaneFrom(_:)))
        hidePlanesGestureRecognizer.minimumPressDuration = 1.0
        hidePlanesGestureRecognizer.numberOfTapsRequired = 2
        self.sceneView.addGestureRecognizer(hidePlanesGestureRecognizer)
    }

    // MARK: - Gesture Recognizers

    @objc func handleTapFrom(_ recognizer: UITapGestureRecognizer) {
        // Take the screen space tap coordinates and pass them to the
        // hitTest method on the ARSCNView instance
        let tapPoint = recognizer.location(in: self.sceneView)

        // If the intersection ray passes through any plane geometry they
        // will be returned, with the planes ordered by distance
        // from the camera
        let results = self.sceneView.hitTest(tapPoint, types: .existingPlaneUsingExtent)
        if let hitResult = results.first {
            self.insertGeometry(hitResult)
        }
    }

    @objc func handleHoldFrom(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }

        // Perform a hit test using the screen coordinates to see if the user pressed on
        // a plane.
        let holdPoint = recognizer.location(in: self.sceneView)
        let results = self.sceneView.hitTest(holdPoint, types: .existingPlaneUsingExtent)
        if let hitResult = results.first {
            DispatchQueue.main.async {
                self.explode(hitResult)
            }
        }
    }

    @objc func handleHidePlaneFrom(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }

        // Hide all the planes
        for (_, plane) in self.planes {
            plane.hide()
        }

        // Stop detecting new planes or updating existing ones.
        // Init a new Configuration instance without planeDetection set.
        let configuration = ARWorldTrackingSessionConfiguration()
        self.sceneView.session.run(configuration)
    }

    // MARK: - Helper functions

    func explode(_ hitResult: ARHitTestResult) {
        // For an explosion, we take the world position of the explosion and the position of each piece of geometry
        // in the world. We then take the distance between those two points, the closer to the explosion point the
        // geometry is the stronger the force of the explosion.

        // The hitResult will be a point on the plane, we move the explosion down a little bit below the
        // plane so that the goemetry fly upwards off the plane
        let explosionYOffset = Float(0.1)

        let position = SCNVector3Make(
            hitResult.worldTransform[3].x,
            hitResult.worldTransform[3].y - explosionYOffset,
            hitResult.worldTransform[3].z
        )

        // We need to find all of the geometry affected by the explosion, ideally we would have some
        // spatial data structure like an octree to efficiently find all geometry close to the explosion
        // but since we don't have many items, we can just loop through all of the current geoemtry
        for box in boxes {
            var distance = SCNVector3Make(
                box.worldPosition.x - position.x,
                box.worldPosition.y - position.y,
                box.worldPosition.z - position.z
            )

            let len = sqrtf(distance.x * distance.x + distance.y * distance.y + distance.z + distance.z)

            let maxDistance = Float(2.0)
            let scale = max(0, (maxDistance - len))
            // Scale the force of the explosion
            let explosionScale = scale * scale * 2

            // Scale the distance vector to the appropriate scale
            distance.x = distance.x / len * explosionScale
            distance.y = distance.y / len * explosionScale
            distance.z = distance.z / len * explosionScale

            // Apply a force to the geometry. We apply the force at one of the corners of the cube
            // to make it spin more, vs just at the center
            box.physicsBody?.applyForce(distance, at: SCNVector3Make(0.05, 0.05, 0.05), asImpulse: true)
        }
    }

    func insertGeometry(_ hitResult: ARHitTestResult) {
        let dimension = CGFloat(0.1)
        let cube = SCNBox(width: dimension, height: dimension, length: dimension, chamferRadius: 0)

        let node = SCNNode(geometry: cube)
        // The physicsBody tells SceneKit this geometry should be
        // manipulated by the physics engine
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.physicsBody?.mass = 2.0
        node.physicsBody?.categoryBitMask = CollisionCategoryCube

        // We insert the geometry slightly above the point the user tapped
        // so that it drops onto the plane using the physics engine
        let insertionYOffset = Float(0.5)
        node.position = SCNVector3Make(
            hitResult.worldTransform[3].x,
            hitResult.worldTransform[3].y + insertionYOffset,
            hitResult.worldTransform[3].z
        )

        // Add the cube to the scene
        self.sceneView.scene.rootNode.addChildNode(node)

        // Add the cube to an internal list for book-keeping
        self.boxes.append(node)
    }

    // MARK: - ARSCNViewDelegate

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor else { return }

        let plane = Plane(with: anchor)
        self.planes[anchor.identifier] = plane
        node.addChildNode(plane)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let existingPlane = planes[anchor.identifier], let anchor = anchor as? ARPlaneAnchor {
            existingPlane.update(anchor)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        self.planes.removeValue(forKey: anchor.identifier)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
}
