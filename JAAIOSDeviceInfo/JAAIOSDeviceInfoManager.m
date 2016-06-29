#import "JAAIOSDeviceInfoManager.h"
#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>


static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *NameMap(void);


@interface JAAIOSDeviceInfoManager ()

@property (readonly) NSCache<NSString *, NSImage *> *iconCache;

@end


static void NormalizeIdentifier(NSString *deviceIdentifier, NSString **normalizedIdentifier, BOOL *isSimulator);


@implementation JAAIOSDeviceInfoManager
{
    dispatch_group_t	_findSimulatorWorkGroup;
    NSURL				*_simulatorURL;
}

- (instancetype)init
{
	self = [super init];

	if (self != nil) {
		// Immediately start asynchronously searching for the iOS Simulator, since this can take an arbitrarily long time.
		_findSimulatorWorkGroup = dispatch_group_create();
		dispatch_group_async(_findSimulatorWorkGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[self findIOSSimulator];
		});
		dispatch_group_notify(_findSimulatorWorkGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			_findSimulatorWorkGroup = nil;
		});

		_iconCache = [NSCache new];
	}

    return self;
}


- (NSString *)nameForDevice:(NSString *)deviceIdentifier
{
	NormalizeIdentifier(deviceIdentifier, &deviceIdentifier, nil);
	NSString *result = NameMap()[deviceIdentifier][@"long"];
	if (result == nil) {
		NSString *UTI = [self selectUTIForDevice:deviceIdentifier color:nil];
		if (UTI != nil) {
			result = CFBridgingRelease(UTTypeCopyDescription((__bridge CFStringRef)UTI));
		}
	}
    if (result == nil && [self identifierIsUnspecificSimulator:deviceIdentifier])  result = @"Simulator";
    if (result == nil)  result = deviceIdentifier;
    return result;
}


- (NSString *)shortNameForDevice:(NSString *)deviceIdentifier
{
	NormalizeIdentifier(deviceIdentifier, &deviceIdentifier, nil);
	NSString *result = NameMap()[deviceIdentifier][@"short"];
	if (result == nil) {
		/* Derive a short name from the long name.
		   Currently, this just strips trailing parenthesised phrases - usually a list of model numbers.
		   There are cases with multiple parenthesized phrases, like "iPad Pro (12.9-inch) (Model A1584)". In this case,
		   stripping only the last set of parentheses is correct.
		 */
		static NSRegularExpression *regexp;
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			regexp = [NSRegularExpression regularExpressionWithPattern:@"(.*) \\(.*\\)" options:0 error:nil];
		});

		NSString *longName = [self nameForDevice:deviceIdentifier];
		NSArray<NSTextCheckingResult *> *matches = [regexp matchesInString:longName options:0 range:(NSRange){ 0, longName.length }];
		if (matches.count > 0) {
			result = [longName substringWithRange:[matches[0] rangeAtIndex:1]];
		} else {
			result = longName;
		}
	}
	return result;
}


- (NSImage *)iconForDevice:(NSString *)deviceIdentifier color:(NSString *)colorCode
{
	if (deviceIdentifier == nil)  return nil;
	if (colorCode.length == 0)  colorCode = nil;

	NSString *fullDeviceIdentifier = deviceIdentifier;
	BOOL isSimulator;
	NormalizeIdentifier(fullDeviceIdentifier, &deviceIdentifier, &isSimulator);

	if (colorCode == nil && [deviceIdentifier isEqualToString:@"Watch1,1"])
	{
		// The default icon for the 38mm watch is actually a gold 42mm watch. This overrides it to a steel 38mm watch.
		colorCode = @"5";
	}

	NSString *cacheKey = [NSString stringWithFormat:@"%@:%@", fullDeviceIdentifier, colorCode];


	NSImage *image = [self.iconCache objectForKey:cacheKey];
	if (image == nil)
	{
		if ([self identifierIsUnspecificSimulator:deviceIdentifier]) {
			image = self.iconForSimulator;
		}
		else {
			image = [self lookupIconForDevice:deviceIdentifier color:colorCode];
			if (isSimulator) {
				image = [self badgeIconWithSimulatorIcon:image];
			}
		}
		if (image != nil)  [self.iconCache setObject:image forKey:cacheKey];
	}

	return image;
}


#pragma mark - Internal

- (NSImage *)lookupIconForDevice:(NSString *)deviceIdentifier color:(NSString *)colorCode
{
	NSParameterAssert(deviceIdentifier != nil);

	NSString *UTI = [self selectUTIForDevice:deviceIdentifier color:colorCode];
	if (UTI == nil)  return nil;
	return [NSWorkspace.sharedWorkspace iconForFileType:UTI];
}


- (NSImage *)badgeIconWithSimulatorIcon:(NSImage *)baseIcon
{
	NSImage *simulatorIcon = [self iconForSimulator];
	if (baseIcon == nil)  return simulatorIcon;

	return [NSImage imageWithSize:baseIcon.size flipped:NO drawingHandler:^(NSRect rect) {
		[baseIcon drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
		NSRect badgeRect = { .origin = { rect.origin.x + rect.size.width / 16, rect.origin.y + rect.size.height / 16 },
							 .size = { rect.size.width / 2, rect.size.height / 2 }};
		[simulatorIcon drawInRect:badgeRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
		return YES;
	}];
}


- (NSString *)selectUTIForDevice:(NSString *)deviceIdentifier color:(NSString *)colorCode
{
	NSParameterAssert(deviceIdentifier != nil);

	CFStringRef deviceIdentifierCF = (__bridge CFStringRef)deviceIdentifier;

	if (colorCode.length > 0) {
		if ([colorCode hasPrefix:@"#"])  colorCode = [colorCode substringFromIndex:1];
		NSString *colorSuffix = [@"-" stringByAppendingString:colorCode];

		CFArrayRef allIdentifiers = UTTypeCreateAllIdentifiersForTag(CFSTR("com.apple.device-model-code"),
		                                                             deviceIdentifierCF,
		                                                             CFSTR("public.device"));
		CFAutorelease(allIdentifiers);

		for (NSString *identifier in (__bridge NSArray *)allIdentifiers) {
			if ([identifier hasSuffix:colorSuffix])  return identifier;
		}
	}

	CFStringRef result = UTTypeCreatePreferredIdentifierForTag(CFSTR("com.apple.device-model-code"),
	                                                           deviceIdentifierCF, nil);
	if (UTTypeIsDynamic(result)) {
		CFRelease(result);
		return nil;
	} else {
		return CFBridgingRelease(result);
	}
}


- (NSArray<NSString *> *)allUTIsForDeviceIdentifier:(NSString *)deviceIdentifier
{
	CFStringRef deviceIdentifierCF = (__bridge CFStringRef)deviceIdentifier;
	CFArrayRef allIdentifiers = UTTypeCreateAllIdentifiersForTag(CFSTR("com.apple.device-model-code"),
	                                                             deviceIdentifierCF,
	                                                             CFSTR("public.device"));
	return CFBridgingRelease(allIdentifiers);
}


- (void)findIOSSimulator
{
	_simulatorURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.apple.iphonesimulator"];
}


- (bool)identifierIsUnspecificSimulator:(NSString *)deviceIdentifier
{
    /*
	 * In the simulator, uname/sysctl hw.machine returns the host Mac's value,
	 * which is the processor type. UIDevice+JAAExtendedDeviceInfo will give
	 * "Simulator" if the environment variable path fails.
	 */
    return [deviceIdentifier isEqualToString:@"x86_64"] ||
	       [deviceIdentifier isEqualToString:@"i386"] ||
           [deviceIdentifier isEqualToString:@"Simulator"];
}


- (void)waitToFindSimulator
{
	if (_findSimulatorWorkGroup)
	{
		// Wait for Simulator search to complete, but at most one second.
		dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
		dispatch_group_wait(_findSimulatorWorkGroup, timeout);
	}
}


- (NSImage *)iconForSimulator
{
	[self waitToFindSimulator];

    if (_simulatorURL)
    {
        NSImage *icon = [NSWorkspace.sharedWorkspace iconForFile:_simulatorURL.path];
        if (icon)  return icon;
    }

    // Generic app icon. Oddly, "com.apple.application" and "app" don't work here.
    return [NSWorkspace.sharedWorkspace iconForFileType:NSFileTypeForHFSTypeCode('APPL')];
}

@end


static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *NameMap(void)
{
	static NSDictionary *nameMap;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		// Note: system-provided names aren't localized either
		nameMap = @{
			@"iPod1,1": @{ @"long": @"iPod touch (1st generation)", @"short": @"iPod touch (1st generation)" },
			@"iPod2,1": @{ @"long": @"iPod touch (2nd generation)", @"short": @"iPod touch (2nd generation)" },
			@"iPod3,1": @{ @"long": @"iPod touch (3rd generation)", @"short": @"iPod touch (3rd generation)" },
			@"iPod4,1": @{ @"long": @"iPod touch (4th generation)", @"short": @"iPod touch (4th generation)" },
			// 5th and 6th have full long names by default
			@"iPod5,1": @{ @"short": @"iPod touch (5th generation)" },
			@"iPod7,1": @{ @"short": @"iPod touch (6th generation)" },

			// iPad 3 was confusingly just named "iPad"
			@"iPad3,2": @{ @"long": @"iPad 3 Wi-Fi + 4G (LTE/CDMA)" },
			@"iPad3,3": @{ @"long": @"iPad 3 Wi-Fi + 4G (LTE/GSM)" },

			// iPad 4 has "4th generation" in parentheses, unlike other iPads
			@"iPad3,4": @{ @"short": @"iPad 4" },
			@"iPad3,5": @{ @"short": @"iPad 4" },
			@"iPad3,6": @{ @"short": @"iPad 4" },

			// Gen 2 and 3 have explicit (nth generation), gen 4 doesn't by default
			@"AppleTV5,3": @{ @"long": @"Apple TV (4th generation)" },
		};
	});

	return nameMap;
}


static void NormalizeIdentifier(NSString *deviceIdentifier, NSString **normalizedIdentifier, BOOL *isSimulator)
{
#define SimulatorSuffix "Simulator"
	BOOL hasSuffix = [deviceIdentifier hasSuffix:@SimulatorSuffix];
	if (hasSuffix) {
		deviceIdentifier = [deviceIdentifier substringToIndex:deviceIdentifier.length - strlen(SimulatorSuffix)];
		if ([deviceIdentifier hasSuffix:@";"] || [deviceIdentifier hasSuffix:@" "]) {
			deviceIdentifier = [deviceIdentifier substringToIndex:deviceIdentifier.length - 1];
		}
	}

	if (normalizedIdentifier != nil) {
		*normalizedIdentifier = deviceIdentifier;
	}

	if (isSimulator != nil) {
		*isSimulator = hasSuffix;
	}
}
