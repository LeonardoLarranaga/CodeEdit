//
//  ProjectNavigatorMenuActions.swift
//  CodeEdit
//
//  Created by Leonardo Larrañaga on 10/11/24.
//

import AppKit

extension ProjectNavigatorMenu {
    /// - Returns: the currently selected `CEWorkspaceFile` items in the outline view.
    func selectedItems() -> Set<CEWorkspaceFile> {
        /// Selected items...
        let selectedItems = Set(outlineView.selectedRowIndexes.compactMap {
            outlineView.item(atRow: $0) as? CEWorkspaceFile
        })

        /// Item that the user brought up the menu with...
        if let menuItem = outlineView.item(atRow: outlineView.clickedRow) as? CEWorkspaceFile {
            /// If the item is not in the set, just like in Xcode, only modify that item.
            if !selectedItems.contains(menuItem) {
                return Set([menuItem])
            }
        }

        return selectedItems
    }

    /// Verify if a folder can be mode from selection by getting the amount of parents found in the selected items.
    /// Used to know if we can create a new folder from selection.
    func canCreateFolderFromSelection() -> Bool {
        var uniqueParents: Set<CEWorkspaceFile> = []
        for file in selectedItems() {
            if let parent = file.parent {
                uniqueParents.insert(parent)
            }
        }

        return uniqueParents.count == 1
    }

    /// Action that opens **Finder** at the items location.
    @objc
    func showInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting(selectedItems().map { $0.url })
    }

    /// Action that opens the item, identical to clicking it.
    @objc
    func openInTab() {
        /// Sort the selected items first by their parent and then by name.
        let sortedItems = selectedItems().sorted { (item1, item2) -> Bool in
            /// Get the parents of both items.
            let parent1 = outlineView.parent(forItem: item1) as? CEWorkspaceFile
            let parent2 = outlineView.parent(forItem: item2) as? CEWorkspaceFile

            /// Compare by parent.
            if parent1 != parent2 {
                /// If the parents are different, use their row position in the outline view.
                return outlineView.row(forItem: parent1) < outlineView.row(forItem: parent2)
            } else {
                /// If both items have the same parent, sort them by name.
                return item1.name < item2.name
            }
        }

        /// Open the items in order.
        sortedItems.forEach { item in
            workspace?.editorManager?.openTab(item: item)
        }
    }

    /// Action that opens in an external editor
    @objc
    func openWithExternalEditor() {
        /// Using  `Process` to open all of the selected files at the same time.
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = selectedItems().map { $0.url.absoluteString }
        try? process.run()
    }

    // TODO: allow custom file names
    /// Action that creates a new untitled file
    @objc
    func newFile() {
        guard let item else { return }
        do {
            try workspace?.workspaceFileManager?.addFile(fileName: "untitled", toFile: item)
        } catch {
            let alert = NSAlert(error: error)
            alert.addButton(withTitle: "Dismiss")
            alert.runModal()
        }
        outlineView.reloadData()
        outlineView.expandItem(item.isFolder ? item : item.parent)
    }

    // TODO: allow custom folder names
    /// Action that creates a new untitled folder
    @objc
    func newFolder() {
        guard let item else { return }
        workspace?.workspaceFileManager?.addFolder(folderName: "untitled", toFile: item)
        outlineView.expandItem(item)
        outlineView.expandItem(item.isFolder ? item : item.parent)
    }

    /// Creates a new folder with the items selected.
    @objc
    func newFolderFromSelection() {
        guard let workspace, let workspaceFileManager = workspace.workspaceFileManager else { return }

        let selectedItems = selectedItems()
        guard let parent = selectedItems.first?.parent else { return }

        /// Get 'New Folder' name.
        var newFolderURL = parent.url.appendingPathComponent("New Folder", conformingTo: .folder)
        var folderNumber = 0
        while workspaceFileManager.fileManager.fileExists(atPath: newFolderURL.path) {
            folderNumber += 1
            newFolderURL = parent.url.appendingPathComponent("New Folder \(folderNumber)")
        }

        for selectedItem in selectedItems where selectedItem.url != newFolderURL {
            workspaceFileManager.move(file: selectedItem, to: newFolderURL.appending(path: selectedItem.name))
        }

        outlineView.reloadData()
        outlineView.expandItem(parent.isFolder ? parent : parent.parent)
    }

    /// Opens the rename file dialogue on the cell this was presented from.
    @objc
    func renameFile() {
        let row = outlineView.row(forItem: item)
        guard row > 0,
              let cell = outlineView.view(
                atColumn: 0,
                row: row,
                makeIfNecessary: false
              ) as? ProjectNavigatorTableViewCell else {
            return
        }
        outlineView.window?.makeFirstResponder(cell.textField)
    }

    /// Action that moves the item to trash.
    @objc
    func trash() {
        selectedItems().forEach { item in
            workspace?.workspaceFileManager?.trash(file: item)
        }
    }

    /// Action that deletes the item immediately.
    @objc
    func delete() {
        selectedItems().forEach { item in
            workspace?.workspaceFileManager?.delete(file: item)
        }
    }

    /// Action that duplicates the item
    @objc
    func duplicate() {
        selectedItems().forEach { item in
            workspace?.workspaceFileManager?.duplicate(file: item)
        }
    }
}