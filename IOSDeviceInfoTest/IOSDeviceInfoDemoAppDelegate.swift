import AppKit

extension NSMenuItem {
	convenience init(title: String, representedObject: AnyObject?) {
		self.init(title: title, action: nil, keyEquivalent: "")
		self.representedObject = representedObject
	}
}


private class DeviceDescription: NSObject {
	let identifier: String
	let colors: [String]

	init(identifier: String, colors: [String]) {
		self.identifier = identifier
		self.colors = colors
		super.init()
	}
}


class IOSDeviceInfoDemoAppDelegate: NSObject, NSApplicationDelegate {
	@IBOutlet var window: NSWindow!
	@IBOutlet var devicePopup: NSPopUpButton!
	@IBOutlet var colorPopup: NSPopUpButton!
	@IBOutlet var deviceIdentifierField: NSTextField!
	@IBOutlet var iconImageView: NSImageView!

	private let infoManager = JAAIOSDeviceInfoManager()
	private var useSimulatorIdentifier = false

	func applicationDidFinishLaunching(_: Notification) {
		let deviceMenu = NSMenu()
		var selectedItem: NSMenuItem? = nil

		for device in self.knownDevicesOrFail() {
			let item = self.menuItem(device: device)
			deviceMenu.addItem(item)
			if device.identifier == "iPhone1,1" {
				selectedItem = item
			}
		}

		self.devicePopup.menu = deviceMenu
		self.devicePopup.select(selectedItem)

		self.deviceSelected(nil)
	}

	private func menuItem(device: DeviceDescription) -> NSMenuItem {
		return NSMenuItem(title: self.infoManager.name(forDevice: device.identifier), representedObject: device)
	}

	@IBAction func deviceSelected(_: AnyObject?) {
		guard let device = self.devicePopup.selectedItem?.representedObject as? DeviceDescription else {
			return
		}

		self.rebuildColorMenu(forDevice: device)
		self.update()
	}

	private func rebuildColorMenu(forDevice device: DeviceDescription) {
		let colorMenu = NSMenu()
		colorMenu.addItem(NSMenuItem(title: "Default", representedObject: nil))

		if (device.colors.count > 0) {
			colorMenu.addItem(NSMenuItem.separator())
			for color in device.colors {
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

	@IBAction func simulatorCheckboxSelected(sender: NSButton!) {
		self.useSimulatorIdentifier = sender.state == 1;
		self.update()
	}

	private func update() {
		guard let device = self.devicePopup.selectedItem?.representedObject as? DeviceDescription else { return }
		var deviceIdentifier = device.identifier
		if self.useSimulatorIdentifier {
			deviceIdentifier = "\(deviceIdentifier);Simulator"
		}
		let color = self.colorPopup.selectedItem?.representedObject as? String

		self.iconImageView.objectValue = self.infoManager.icon(forDevice: deviceIdentifier, color: color)

		let shortName = self.infoManager.shortName(forDevice: deviceIdentifier)
		self.deviceIdentifierField.objectValue = "\(shortName) (\(deviceIdentifier))"
	}
}


// Hack to let us constrain get() below to string-keyed dictionaries for better error reporting.
private protocol StringConstraint {}
extension String: StringConstraint {}

private extension Dictionary where Key: StringConstraint, Value: AnyObject {
	func get<T>(_ key: Key) throws -> T {
		guard let result = self[key] as? T else {
			throw NSError(domain: "SchemaError", code: 1, userInfo: ["key": key as! String])
		}
		return result
	}
}

// This apparently can't be done as an extension method because lol.
private func appendArrayInDictionary<Key, Element>(_ dictionary: inout [Key: [Element]], key: Key, element: Element) {
	if dictionary[key] == nil {
		dictionary[key] = [element]
	} else {
		dictionary[key]!.append(element)
	}
}


// MARK: Device listing

private extension IOSDeviceInfoDemoAppDelegate {
	func knownDevicesOrFail() -> [DeviceDescription] {
		do {
			return try self.knownDevices()
		} catch let error as NSError {
			NSApplication.shared().presentError(error)
			NSApplication.shared().terminate(nil)
			abort()
		}
	}

	/**
	 * Return DeviceDescriptions for all device types LaunchServices knows about.
	 *
	 * Unfortunately, there's no way to iterate over subtypes of a UTI (e.g. all types conforming to com.apple.iphone),
	 * so for demo purposes we read the plist file where the UTIs are declared. This is more fragile than the actual
	 * JAAIOSDeviceInfoManager implementation, but the file has been in the same place for at least five macOS versions.
	 */
	func knownDevices() throws -> [DeviceDescription] {
		let path = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Library/MobileDevices.bundle/Contents/Info.plist"
		let url = URL(fileURLWithPath: path)
		let data = try Data(contentsOf: url)
		let contents = try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: AnyObject]
		let declarations: [[String : AnyObject]] = try contents.get("UTExportedTypeDeclarations")

		/* Build a dictionary of deviceID -> [ UTI ], where deviceID is an iPhone1,1-type identifier. Also keep track
		   of the order they were encountered in since they're in a sensible order in the file.
		 */
		let orderedDeviceIdentifiers = NSMutableOrderedSet()
		var identifiersByDeviceID: [String: [String]] = [:]
		for declaration in declarations {
			guard let deviceID = self.deviceIdentifier(forUTIDeclaration: declaration) else { continue }

			let identifier: String = try declaration.get("UTTypeIdentifier")
			appendArrayInDictionary(&identifiersByDeviceID, key: deviceID, element: identifier)

			orderedDeviceIdentifiers.add(deviceID)
		}

		// Extract color codes and pack what we've learned into DeviceDescriptions.
		var result: [DeviceDescription] = []
		for deviceID in orderedDeviceIdentifiers {
			let deviceIdentifier = deviceID as! String
			let colors = self.colorCodeList(fromIdentifiers: identifiersByDeviceID[deviceIdentifier]!)

			result.append(DeviceDescription(identifier: deviceIdentifier, colors: colors))
		}

		// Add Simulator item.
		result.append(DeviceDescription(identifier: "x86_64", colors: []))

		return result
	}

	/**
	 * Given a UTI declaration dictionary, search its com.apple.device-model-code for a value with a prefix matching
	 * known device model identifier patterns. This is needed because com.apple.device-model-code also contains values
	 * for SKU numbers.
	 */
	func deviceIdentifier(forUTIDeclaration declaration: [String: AnyObject]) -> String? {
		let deviceIdentifierPrefixes = ["iPhone", "iPod", "iPad", "AppleTV", "Watch"]
		func isDeviceIdentifierModelCode(_ code: String) -> Bool {
			return deviceIdentifierPrefixes.reduce(false) {
				accumulator, prefix in
				accumulator || code.hasPrefix(prefix)
			}
		}

		return (declaration["UTTypeTagSpecification"]?["com.apple.device-model-code"] as? [String])?
			.filter(isDeviceIdentifierModelCode)
			.first
	}

	/**
	 * The general form for device UTIs is com.apple.device-type-color. Given an array of UTIs with the same device
	 * model identifier in their com.apple.device-model-code tag – such as ["com.apple.device-type-colorA",
	 * "com.apple.device-type-colorB"] – this finds and strips the common prefix, giving ["colorA", "colorB"].
	 *
	 * For single-color devices, we return an empty array and display a Default option in a disabled pop-up menu.
	 */
	func colorCodeList(fromIdentifiers identifiers : [String]) -> [String] {
		if identifiers.count < 2 {
			return []
		}

		let longestCommonPrefix = identifiers.reduce(identifiers[0]) {
			$0.commonPrefix(with: $1, options: [.literalSearch])
		}
		let prefixLength = (longestCommonPrefix as NSString).length
		return identifiers.map {
			($0 as NSString).substring(from: prefixLength)
		}
	}
}
