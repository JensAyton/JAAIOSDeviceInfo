#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A class for extracting iOS/watchOS/tvOS device information from the Launch
 * Services UTI database.
 *
 * Since this relies on undocumentated data sources, it should not be relied
 * on in production, but it's quite useful for making debugging tools prettier.
 *
 * Since the information comes from the system, users with out-of-date systems
 * will not be able to retrieve information for newer devices.
 *
 * JAAIOSDeviceInfoManager is fully thread-safe; a single instance may be used
 * from multiple threads at once. Lookup operations are usually fast, but this
 * isn't guaranteed – for instance, retrieving the Simulator icon could
 * potentially trigger Spotlight indexing.
 */
@interface JAAIOSDeviceInfoManager: NSObject

/**
 * Given a device identifier string (such as "iPhone2,1"), returns a
 * descriptive name of the device type.
 *
 * This full name often, but not always, includes one or more model numbers
 * and details about types of cellular connections. In some cases, Apple's
 * official names are enhanced to make it easier to tell models apart (for
 * instance, referring to the third-generation iPad as "iPad 3" rather than
 * "iPad", and adding generation number to iPad touch models).
 *
 * @param deviceIdentifier An Apple model identifer, such as iPod5,1. This can
 *        be retrieved on device using sysctlbyname("hw.machine", ...).
 * @return A descriptive name for the device. If the device is unknown, the
 *         deviceIdentifier parameter is returned.
 *         (Failure can be detected using pointer equality.)
 */
- (NSString *)nameForDevice:(NSString *)deviceIdentifier;

/**
 * Given a device identifier string (such as "iPhone2,1"), returns a short
 * name of the device type.
 *
 * Like nameForDevice:, but with the model numbers and cellular connection
 * details stripped out (in most cases algorithmically).
 *
 * @param deviceIdentifier An Apple model identifer, such as iPod5,1. This can
 *        be retrieved on device using sysctlbyname("hw.machine", ...).
 * @return A short name for the device. If the device is unknown, the
 *         deviceIdentifier parameter is returned.
 *         (Failure can be detected using pointer equality.)
 */
- (NSString *)shortNameForDevice:(NSString *)deviceIdentifier;

/**
 * Given a device identifier string (such as "iPhone2,1"), returns an icon for
 * the device.
 *
 * @param deviceIdentifier An Apple model identifer, such as iPod5,1. This can
 *        be retrieved on device using sysctlbyname("hw.machine", ...).
 * @param color An optional colour identifier, such as "black" or "white".
 * @return An image, if one could be found.
 */
- (nullable NSImage *)iconForDevice:(NSString *)deviceIdentifier
                              color:(nullable NSString *)color;

@end

NS_ASSUME_NONNULL_END
