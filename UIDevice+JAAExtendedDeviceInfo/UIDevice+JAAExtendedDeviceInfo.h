#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef JAAEXTENDEDDEVICEINFO_USE_PRIVATE_API
#define JAAEXTENDEDDEVICEINFO_USE_PRIVATE_API DEBUG
#endif


@interface UIDevice (JAAExtendedDeviceInfo)

/**
 * Returns the device's model identifier, a string such as "iPhone8,1".
 *
 * In the simulator, attempts to return the identifier of the simulated
 * device; if this is not possible, it falls back to "Simulator".
 */
@property(nonatomic,readonly,getter=jaa_modelIdentifier) NSString *modelIdentifier;

/**
 * Returns the device's model identifier, a string such as "iPhone8,1".
 *
 * In the simulator, attempts to return the identifier of the simulated
 * device with ";Simulator" appended (e.g., "iPhone8,1;Simulator"); if this is
 * not possible, it falls back to "Simulator".
 */
@property(nonatomic,readonly,getter=jaa_modelIdentifierDistinguishingSimulator) NSString *modelIdentifierDistinguishingSimulator;

/**
 * Returns the color code for the device.
 *
 * This requires the use of undocumented APIs, so it will always return nil
 * unless JAAEXTENDEDDEVICEINFO_USE_PRIVATE_API is defined and non-zero.
 *
 * On older devices (iPhone 4 and 4s, iPod touch 4th and 5th generation, iPad
 * iPad 2–4 and iPad mini 1) this is a name like “white” or “slate“. On newer
 * iOS devices, it's a hex color code like "#d6c8b9". On Apple Watch, the
 * colors are merely numbered from 1 to 9.
 */
@property(nonatomic,readonly,nullable,getter=jaa_deviceColor) NSString *deviceColor;

@end

NS_ASSUME_NONNULL_END
