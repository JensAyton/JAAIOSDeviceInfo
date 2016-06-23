import AppKit


extension NSMenuItem {
	convenience init(title: String, representedObject: AnyObject?) {
		self.init(title: title, action: nil, keyEquivalent: "")
		self.representedObject = representedObject
	}
}


class IOSDeviceInfoDemoAppDelegate: NSObject, NSApplicationDelegate {
	@IBOutlet var window: NSWindow!
	@IBOutlet var devicePopup: NSPopUpButton!
	@IBOutlet var colorPopup: NSPopUpButton!
	@IBOutlet var deviceIdentifierField: NSTextField!
	@IBOutlet var iconImageView: NSImageView!

	private let infoManager = JAAIOSDeviceInfoManager()

	func applicationDidFinishLaunching(_: Notification) {
		let deviceMenu = NSMenu()
		for deviceIdentifier in self.infoManager.knownDevices {
			deviceMenu.addItem(self.menuItem(deviceIdentifier: deviceIdentifier))
		}

		// Add Simulator item
		deviceMenu.addItem(NSMenuItem.separator())
		deviceMenu.addItem(self.menuItem(deviceIdentifier: "x86_64"))

		self.devicePopup.menu = deviceMenu
		self.devicePopup.selectItem(at: self.devicePopup.indexOfItem(withRepresentedObject: "iPhone1,1"))

		self.deviceSelected(nil)
	}

	private func menuItem(deviceIdentifier: String) -> NSMenuItem {
		return NSMenuItem(title: self.infoManager.name(forDevice: deviceIdentifier), representedObject: deviceIdentifier)
	}

	@IBAction func deviceSelected(_: AnyObject?) {
		guard let deviceIdentifier = self.devicePopup.selectedItem?.representedObject as? String else {
			return
		}

		let name = self.infoManager.name(forDevice: deviceIdentifier)
		self.deviceIdentifierField.objectValue = "\(name) (\(deviceIdentifier))"

		self.rebuildColorMenu(forDevice: deviceIdentifier)

		self.update()
	}

	private func rebuildColorMenu(forDevice deviceIdentifier: String) {
		let colorMenu = NSMenu()
		colorMenu.addItem(NSMenuItem(title: "Default", representedObject: ""))
		let colors = self.infoManager.knownColors(forDevice: deviceIdentifier)
		if (colors.count > 0) {
			colorMenu.addItem(NSMenuItem.separator())
			for color in colors {
				colorMenu.addItem(NSMenuItem(title: color, representedObject: color))
			}
			self.colorPopup.isEnabled = true
		} else {
			self.colorPopup.isEnabled = false
		}
		self.colorPopup.menu = colorMenu
		self.colorPopup.selectItem(at: 0)
	}

	@IBAction func colorSelected(_: AnyObject?) {
		self.update()
	}

	private func update() {
		guard let deviceIdentifier = self.devicePopup.selectedItem?.representedObject as? String,
			      color = self.colorPopup.selectedItem?.representedObject as? String
		else {
			return
		}

		self.iconImageView.objectValue = self.infoManager.icon(forDevice: deviceIdentifier, color: color);
	}
}
