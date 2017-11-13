import Cocoa


func colorSwatch(forColorCode colorCode: String) -> NSImage? {
	return color(forColorCode: colorCode).map {
		color in
		return NSImage(size: NSSize(width: 16, height: 16), flipped: false) {
			rect in
			color.setFill()
			NSBezierPath.fill(rect)
			return true
		}
	}
}

func color(forColorCode colorCode: String) -> NSColor? {
	var code = colorCode

	switch colorCode {
		/* Remap named colors mostly to corresponding iPhone 5c and iPod touch
		 * (6th generation) colors.
		 */
		case "white": code = "f5f4f7"
		case "black": code = "3b3b3c"
		case "slate": code = "3b3b3c"
		case "blue": code = "46abe0"
		case "red": code = "c6353f"
		case "yellow": code = "faf189"
		case "pink": code = "fe767a"
		case "silver": code = "f5f4f7"
		case "slate": code = "3b3b3c"
		case "sparrow": code = "3b3b3c"

		default:
			if code.hasPrefix("#") {
				code.remove(at: code.startIndex)
			}
	}

	let hexits = code.map {
		strtoul(String($0), nil, 16)
	}
	guard hexits.count == 6 else { return nil }

	let red = hexits[0] * 16 + hexits[1]
	let green = hexits[2] * 16 + hexits[3]
	let blue = hexits[4] * 16 + hexits[5]

	return NSColor(srgbRed: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
}
