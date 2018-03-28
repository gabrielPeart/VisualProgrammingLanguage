//
//  CanvasViewController.swift
//  VPL
//
//  Created by Nathan Flurry on 3/13/18.
//  Copyright © 2018 Nathan Flurry. All rights reserved.
//

import UIKit

class CanvasViewController: UIViewController {
    /// Shortcut for help.
    var helpShortcut: String = "H"
    
    /// Shortcut for custom node popover.
    var customNodeShortcut: String = "X"
    
    /// Shortcut for loading/saving.
    var loadShortcut: String = "L"
    
    /// View nodes that can be created.
    var spawnableNodes: [DisplayableNode.Type] = [] {
        willSet {
            // Make sure there are no duplicate shortcuts
            for (i, node) in newValue.enumerated() {
                if let shortcut = node.shortcutCharacter {
                    for j in (i+1)..<newValue.count {
                        assert(shortcut != newValue[j].shortcutCharacter)
                    }
                }
            }
        }
    }
    
    /// Output of the code.
    var outputView: UITextView!
    
    /// Canvas that holds all of the nodes
    var nodeCanvas: DisplayNodeCanvas!
    
    /// Canvas for all of the drawing for quick shortcuts
    var drawingCanvas: DrawingCanvas!
    
    /// Timer for committing shortcuts
    var commitDrawingTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add the text
        outputView = UITextView(frame: CGRect.zero)
        outputView.isEditable = false
        outputView.isSelectable = true
        view.addSubview(outputView)
        outputView.translatesAutoresizingMaskIntoConstraints = false
        outputView.rightAnchor.constraint(equalTo: view.rightAnchor).activate()
        outputView.topAnchor.constraint(equalTo: view.topAnchor).activate()
        outputView.bottomAnchor.constraint(equalTo: view.bottomAnchor).activate()
        outputView.widthAnchor.constraint(equalToConstant: 180).activate()
        
        // Add the node canvas
        nodeCanvas = DisplayNodeCanvas(frame: CGRect.zero)
        nodeCanvas.updateCallback = {
            let assembled = self.nodeCanvas.assemble()
            self.outputView.text = assembled
        }
        view.addSubview(nodeCanvas)
        nodeCanvas.translatesAutoresizingMaskIntoConstraints = false
        nodeCanvas.leftAnchor.constraint(equalTo: view.leftAnchor).activate()
        nodeCanvas.topAnchor.constraint(equalTo: view.topAnchor).activate()
        nodeCanvas.bottomAnchor.constraint(equalTo: view.bottomAnchor).activate()
        nodeCanvas.rightAnchor.constraint(equalTo: outputView.leftAnchor).activate()
        
        // Add drawing canvas
        drawingCanvas = DrawingCanvas(frame: view.bounds)
        drawingCanvas.onInputStart = {
            // Cancel the timer
            self.commitDrawingTimer?.invalidate()
            self.commitDrawingTimer = nil
        }
        drawingCanvas.onInputFinish = {
            // Start a timer to commit the drawing
            let timer = Timer(timeInterval: 0.5, repeats: false) { _ in
                // Remove the timer
                self.commitDrawingTimer = nil
                
                // Get the drawing
                guard let output = self.drawingCanvas.complete() else {
                    print("Drawing has no image.")
                    return
                }
                
                // Process
                try! OCRRequest(image: output, singleCharacter: true) { (result, breakdown) in
                    assert(breakdown.count == 1)
                    
                    // Get the character's center
                    guard let firstBreakdown = breakdown.first, let charResult = firstBreakdown else {
                        print("Failed to get first char breakdown.")
                        return
                    }
                    guard case let .some(character, _, charBox) = charResult else {
                        print("Could not get char box.")
                        return
                    }
                    let charCenter = CGPoint(x: charBox.midX, y: charBox.midY)
                    
                    // Present help
                    if character == self.helpShortcut {
                        let alert = UIAlertController(title: "Help", message: nil, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in alert.dismiss(animated: true) }))
                        self.present(alert, animated: true)
                        return
                    }
                    
                    // Present custom node popover
                    if character == self.customNodeShortcut {
                        let alert = UIAlertController(title: "Custom Node", message: nil, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in alert.dismiss(animated: true) }))
                        self.present(alert, animated: true)
                        return
                    }
                    
                    // Present custom node popover
                    if character == self.loadShortcut {
                        let alert = UIAlertController(title: "Load", message: nil, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in alert.dismiss(animated: true) }))
                        self.present(alert, animated: true)
                        return
                    }
                    
                    // Create the node
                    self.createNode(character: character, position: charCenter)
                    
                    // Overlay the breakdown for debug info
                    self.drawingCanvas.overlayOCRBreakdown(breakdown: breakdown)
                }
            }
            RunLoop.main.add(timer, forMode: RunLoopMode.defaultRunLoopMode)
            self.commitDrawingTimer = timer
        }
        view.addSubview(drawingCanvas)
        view.bringSubview(toFront: nodeCanvas)
        drawingCanvas.translatesAutoresizingMaskIntoConstraints = false
        drawingCanvas.leftAnchor.constraint(equalTo: view.leftAnchor).activate()
        drawingCanvas.topAnchor.constraint(equalTo: view.topAnchor).activate()
        drawingCanvas.bottomAnchor.constraint(equalTo: view.bottomAnchor).activate()
        drawingCanvas.rightAnchor.constraint(equalTo: outputView.leftAnchor).activate()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @discardableResult
    func createNode(character: String, position: CGPoint) -> DisplayNode? {
        // Find the node
        guard let nodeType = spawnableNodes.first(where: { $0.shortcutCharacter == character }) else {
            return nil
        }
        
        // Create the node
        let node = nodeType.init()
        
        // Create and insert the display node
        let displayNode = DisplayNode(node: node)
        displayNode.layoutIfNeeded()
        displayNode.center = position
        nodeCanvas.insertNode(node: displayNode)
        
        return displayNode
    }
}
