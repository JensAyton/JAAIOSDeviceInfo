#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A class which knows how to extract iOS device icons from iTunes using evil black magic. It can also provide
 * human-readable names as a bonus.
 * 
 * Given the hacky nature and inherent fragility of this code, it is suggested that it be used with caution - in
 * debugging tools, for instance.
 */
@interface JAAIOSDeviceInfoManager: NSObject

/**
 * Given a device identifier string (such as "iPhone2,1"), returns a descriptive name of the device type.
 *
 * These are not necessarily the official product names; for instance, the original iPhone is described as "iPhone 1"
 * and the third-generation iPad without cellular connectivity as "iPad (Gen. 3, WiFi)".
 *
 * @param deviceIdentifer An Apple model identifer, such as iPod5,1. This can be retrieved on device using
 *        sysctlbyname("hw.machine", ...).
 * @return A descriptive name for the device. If the device is unknown, the deviceIdentifier parameter is returned.
 *         (Failure can be detected using pointer equality.)
 */
- (NSString *)nameForDevice:(NSString *)deviceIdentifier;

/**
 * Given a device identifier string (such as "iPhone2,1"), returns an icon for the device. The icons are retrieved from
 * resources in iTunes. If a version of iTunes other than 11.0.4 is installed, who knows what will happen? This is a
 * hack.
 *
 * @param deviceIdentifer An Apple model identifer, such as iPod5,1. This can be retrieved on device using
 *        sysctlbyname("hw.machine", ...).
 * @param colorName An optional colour identifier, such as "black" or "white". (For the fifth generation iPod touch,
 *        colour names "slate", "silver", "pink", "yellow", "blue" and "red" are also included.) I have no idea how to
 *        identify the colour of a device; feel free to tell me if you find a way. If the specified colour is not found,
 *        or nil is passed, an appropriate default is used.
 * @return An image, if one could be found. (Possible reasons for failure include the device identifier being unknown,
 *         iTunes not being installed, or the resource IDs used for the icons having changed; the latter could also
 *         result in the wrong image being returned.)
 */
- (nullable NSImage *)iconForDevice:(NSString *)deviceIdentifier color:(nullable NSString *)color;

/**
 * Given a device identifier string (such as "iPhone2,1"), returns an icon for the device. The icons are retrieved from
 * resources in iTunes. If a version of iTunes other than 11.0.4 is installed, who knows what will happen? This is a
 * hack.
 *
 * @param deviceIdentifer An Apple model identifer, such as iPod5,1. This can be retrieved on device using
 *        sysctlbyname("hw.machine", ...).
 * @return An image, if one could be found. (Possible reasons for failure include the device identifier being unknown,
 *         iTunes not being installed, or the resource IDs used for the icons having changed; the latter could also
 *         result in the wrong image being returned.)
 */
- (nullable NSImage *)iconForDevice:(NSString *)deviceIdentifier;

/**
 * Retrieve a list of supported colour values (as strings) for a device. The list may be empty.
 */
- (NSArray<NSString *> *)knownColorsForDevice:(NSString *)deviceIdentifier;

/**
 * A list of the device identifiers JAAIOSDeviceManager knows about.
 * 
 * Not included: "i386" and "x86_64", which are the hw.machine values for the iOS Simulator.
 */
@property (readonly) NSArray<NSString *> *knownDevices;

@end

NS_ASSUME_NONNULL_END
