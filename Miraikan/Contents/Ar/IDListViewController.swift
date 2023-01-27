//
//  IDListViewController.swift
//  NavCogMiraikan
//
/*******************************************************************************
 * Copyright (c) 2023 © Miraikan - The National Museum of Emerging Science and Innovation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

import Foundation

class IDListViewController: UIViewController {
    
    private let tableView = UITableView()
    
    var arUcoList: [ArUcoModel] = []

    private let prepareIdentifierARMarker = "toARMarkerViewController"

    var selectedId = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        self.view.backgroundColor = .systemBackground
        
        arUcoList = ArUcoManager.shared.arUcoList

        tableView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)

        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension IDListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return arUcoList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "IdARUcoCell")
        cell.textLabel?.numberOfLines = 0
        cell.accessoryType = .detailButton

        if indexPath.row < arUcoList.count {
            let arUcoModel = arUcoList[indexPath.row]
            setCell(cell: cell, arUcoModel: arUcoModel)
            cell.tag = arUcoModel.id
        }
        return cell
    }
}

extension IDListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cell = self.tableView(tableView, cellForRowAt: indexPath)
        if let text = cell.textLabel?.accessibilityLabel {
            AudioManager.shared.forcedSpeak(text: text)
        }
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let cell = self.tableView(tableView, cellForRowAt: indexPath)
        
        self.selectedId = cell.tag
        
        let arMarkerVC = ARMarkerViewController()
        arMarkerVC.selectedId = selectedId
        self.navigationController?.pushViewController(arMarkerVC, animated: true)
    }
}

extension IDListViewController {
    
    @objc func doubleTap(_ gesture: UITapGestureRecognizer) {
        AudioManager.shared.stop()
    }

    func setCell(cell: UITableViewCell, arUcoModel: ArUcoModel) {
        let transform = MarkerWorldTransform()
        transform.distance = 0.9
        transform.horizontalDistance = 0.4
        transform.yaw = 90

        let phonationModel = ArManager.shared.setSpeakStr(arUcoModel: arUcoModel, transform: transform, isDebug: true)
        cell.textLabel?.text = String(arUcoModel.id) + "\n" + phonationModel.string
        cell.textLabel?.accessibilityLabel = phonationModel.phonation
    }
}
