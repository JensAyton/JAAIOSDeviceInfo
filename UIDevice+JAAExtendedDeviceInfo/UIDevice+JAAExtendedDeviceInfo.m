#import "UIDevice+JAAExtendedDeviceInfo.h"
#include <stdlib.h>
#include <sys/utsname.h>

@interface UIDevice (Private)

- (nullable id)_deviceInfoForKey:(NSString *)key;

@end


static NSString *GetModelIdentifier(void)
{
#if TARGET_OS_SIMULATOR
	return @(getenv("SIMULATOR_MODEL_IDENTIFIER"));
#else
	struct utsname info;
	uname(&info);
	return @(info.machine);
#endif
}


@implementation UIDevice (JAAExtendedDeviceInfo)

- (NSString *)jaa_modelIdentifier
{
	NSString *result = GetModelIdentifier();
#if TARGET_OS_SIMULATOR
	if (result == nil)  result = @"Simulator";
#endif
	return result;
}

- (NSString *)jaa_modelIdentifierDistinguishingSimulator
{
	NSString *result = GetModelIdentifier();
#if TARGET_OS_SIMULATOR
	if (result == nil)  result = @"Simulator";
	else  result = [result stringByAppendingString:@";Simulator"];
#endif
	return result;
}

- (NSString *)jaa_deviceColor
{
#if JAAEXTENDEDDEVICEINFO_USE_PRIVATE_API
	return [self _deviceInfoForKey:@"DeviceColor"];
#else
	return nil;
#endif
}

@end
