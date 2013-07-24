#import "JAAIOSDeviceInfoManager.h"
#import <Carbon/Carbon.h>


@implementation JAAIOSDeviceInfoManager
{
    NSDictionary        *_infoDictionary;
    NSCache             *_iconCache;
    dispatch_group_t    _findApplicationsWorkGroup;
    NSArray             *_resourceFileURLs;
    NSURL               *_simulatorURL;
}

- (id)init
{
    if (!(self = [super init]))
        return nil;

    /* Immediately start asynchronously searching for iTunes and listing its resources, and searching for iOS Simulator,
     * since this can take an arbitrarily long time.
     */
    _findApplicationsWorkGroup = dispatch_group_create();
    dispatch_group_async(_findApplicationsWorkGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self findITunes];
    });
    dispatch_group_async(_findApplicationsWorkGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self findIOSSimulator];
    });
    dispatch_group_notify(_findApplicationsWorkGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        _findApplicationsWorkGroup = nil;
    });

    return self;
}


- (NSString *)nameForDevice:(NSString *)deviceIdentifier
{
    NSString *result = self.infoDictionary[deviceIdentifier][@"name"];
    if (result == nil && [self identifierIsSimulator:deviceIdentifier])  result = @"iOS Simulator";
    if (result == nil)  result = deviceIdentifier;
    return result;
}


- (NSImage *)iconForDevice:(NSString *)deviceIdentifier color:(NSString *)color
{
    NSImage *image = [_iconCache objectForKey:deviceIdentifier];
    if (image != nil)  return image;

    if ([self identifierIsSimulator:deviceIdentifier])
    {
        image = [self iconForSimulator];
    }
    else
    {
        image = [self iconForDeviceFromITunes:deviceIdentifier color:color];
    }

    if (image != nil)  [_iconCache setObject:image forKey:deviceIdentifier];
    
    return image;
}


- (NSArray *)knownDevices
{
    return [self.infoDictionary.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}


- (NSArray *)knownColorsForDevice:(NSString *)deviceIdentifier
{
    NSMutableArray *result = [NSMutableArray new];

    for (NSString *key in self.infoDictionary[deviceIdentifier])
    {
        if ([key hasPrefix:@"icon;"])
        {
            NSString *colorKey = [key substringFromIndex:5];
            [result addObject:colorKey];
        }
    }

    return [result sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}


#pragma mark - Internal

- (void)findITunes
{
    // NOTE: -[NSWorkspace URLForApplicationWithBundleIdentifier:] isn't documented as being thread safe, although
    // it probably just calls LSFindApplicationForInfo(), which is.
    CFURLRef cfITunesURL;
    LSFindApplicationForInfo('hook', CFSTR("com.apple.iTunes"), NULL, NULL, &cfITunesURL);
    if (cfITunesURL != NULL)
    {
        [self findResourceFilesInITunes:(__bridge NSURL *)cfITunesURL];
        CFRelease(cfITunesURL);
    }
}


- (void)findResourceFilesInITunes:(NSURL *)iTunesURL
{
    _resourceFileURLs = [NSBundle URLsForResourcesWithExtension:@"rsrc" subdirectory:nil inBundleWithURL:iTunesURL];
}


- (void)findIOSSimulator
{
    // As above.
    CFURLRef cfSimulatorURL;
    LSFindApplicationForInfo(kLSUnknownCreator, CFSTR("com.apple.iphonesimulator"), NULL, NULL, &cfSimulatorURL);
    _simulatorURL = CFBridgingRelease(cfSimulatorURL);
}


- (void)waitToFindITunes
{
    if (_findApplicationsWorkGroup)
    {
        // Wait for iTunes search to complete, but at most one second.
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
        dispatch_group_wait(_findApplicationsWorkGroup, timeout);
    }
}


- (bool)identifierIsSimulator:(NSString *)deviceIdentifier
{
    // In the simulator, sysctl hw.machine returns the Mac's value, which is the processor type.
    return [deviceIdentifier isEqualToString:@"x86_64"] || [deviceIdentifier isEqualToString:@"i386"];
}


// The resource manager is deprecated, but there is no system-provided substitute.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

- (NSImage *)iconForDeviceFromITunes:(NSString *)deviceIdentifier color:(NSString *)color
{
    [self waitToFindITunes];
    if (_resourceFileURLs == nil)  return nil;

    NSNumber *resourceID;
    if (color != nil)
    {
        resourceID = self.infoDictionary[deviceIdentifier][[NSString stringWithFormat:@"icon;%@", color]];
    }
    if (resourceID == nil)
    {
        resourceID = self.infoDictionary[deviceIdentifier][@"icon"];
    }
    if (resourceID == nil)
    {
        return nil;
    }

    // Load all of iTunes's resource files.
    NSMutableArray *fileRefNums = [NSMutableArray new];
    for (NSURL *url in _resourceFileURLs)
    {
        FSRef fsRef;
        bool OK = CFURLGetFSRef((__bridge CFURLRef)url, &fsRef);
        if (!OK)  continue;

        ResFileRefNum refNum;
        OSStatus status = FSOpenResourceFile(&fsRef, 0, NULL, fsRdPerm, &refNum);
        if (status != noErr)  continue;

        [fileRefNums addObject:@(refNum)];
    }

    NSImage *smallImage = [self loadPNGResource:4000 + resourceID.intValue];
    NSImage *largeImage = [self loadPNGResource:19000 + resourceID.intValue];

    for (NSNumber *refNum in fileRefNums)
    {
        CloseResFile(refNum.intValue);
    }

    if (largeImage == nil)  return smallImage;
    // Combine the two images into one multi-representation image.
    if (smallImage)  [largeImage addRepresentations:smallImage.representations];
    return largeImage;
}


- (NSImage *)loadPNGResource:(ResID)resourceID
{
    Handle resource = GetResource('PNG ', resourceID);
    if (resource == NULL)  return nil;

    // Hay guise, did you know we don't need to call HLock() on Mac OS X? Groovy!
    NSData *data = [NSData dataWithBytes:*resource length:GetHandleSize(resource)];
    NSImage *result = [[NSImage alloc] initWithData:data];

    ReleaseResource(resource);
    return result;
}

#pragma clang diagnostic pop


- (NSImage *)iconForSimulator
{
    if (_simulatorURL)
    {
        NSImage *icon = [NSWorkspace.sharedWorkspace iconForFile:_simulatorURL.path];
        if (icon)  return icon;
    }

    // Oddly, "com.apple.application" and "app" don't work here.
    return [NSWorkspace.sharedWorkspace iconForFileType:NSFileTypeForHFSTypeCode('APPL')];
}


- (NSImage *)iconForDevice:(NSString *)deviceIdentifier
{
    return [self iconForDevice:deviceIdentifier color:nil];
}


- (NSDictionary *)infoDictionary
{
    /*
     * NOTE TO TINKERERS: these icon IDs are correct as of iTunes 11.0.4.
     *
     * There are four sets of icons embedded in resource files in iTunes:
     * * 'icns' resources starting at ID 4300
     * * 'PNG ' resources starting at 4400
     * * Larger 'PNG ' resources starting at 19400
     *
     * The two sets of PNGs seem to match up, i.e. 19506 is a bigger version of 4506. The icns resources do not contain
     * all iOS models and have a different numbering sequence. The table below holds the low three digits of each 'PNG '
     * resource.
     *
     * The table contains icon IDs for different device colours. However, I don't know of a useful way to get this
     * information. The Intertubes seem to think it's encoded in device serial numbers, in ways that vary by device
     * type. For iPhones and iPads, the "icon" key is always the black version. For the fifth generation iPod touch,
     * the "icon" key gives the "silver" version.
     */

    if (_infoDictionary == nil)
    {
        _infoDictionary = @{
            @"iPhone1,1":  @{ @"name": @"iPhone 1",                @"icon": @446 },
            @"iPhone1,2":  @{ @"name": @"iPhone 3G",               @"icon": @449 /* 448: 3G lock screen, 449: 3G springboard */ },
            @"iPhone2,1":  @{ @"name": @"iPhone 3GS",              @"icon": @481 },
            @"iPhone3,1":  @{ @"name": @"iPhone 4",                @"icon": @485, @"icon;white": @486 },
            @"iPhone3,2":  @{ @"name": @"iPhone 4 (Rev A)",        @"icon": @485, @"icon;white": @486 },    // The 8 GB budget model
            @"iPhone3,3":  @{ @"name": @"iPhone 4 (CDMA)",         @"icon": @502, @"icon;white": @503 },
            @"iPhone4,1":  @{ @"name": @"iPhone 4S",               @"icon": @506, @"icon;white": @507 },
            @"iPhone5,1":  @{ @"name": @"iPhone 5 (GSM)",          @"icon": @528, @"icon;white": @529 },
            @"iPhone5,2":  @{ @"name": @"iPhone 5 (CDMA)",         @"icon": @528, @"icon;white": @529 },

            @"iPod1,1":    @{ @"name": @"iPod touch (Gen. 1)",     @"icon": @447 },
            @"iPod2,1":    @{ @"name": @"iPod touch (Gen. 2)",     @"icon": @464 },
            @"iPod3,1":    @{ @"name": @"iPod touch (Gen. 3)",     @"icon": @483 /* Same as G2 except it has wallpaper */ },
            @"iPod4,1":    @{ @"name": @"iPod touch (Gen. 4)",     @"icon": @499, @"icon;white": @500 },
            @"iPod5,1":    @{ @"name": @"iPod touch (Gen. 5)",     @"icon": @530, @"icon;silver": @530, @"icon;pink": @531, @"icon;yellow": @532, @"icon;blue": @533, @"icon;slate": @534, @"icon;red": @535, @"icon;white": @530, @"icon;black": @534 },

            @"iPad1,1":    @{ @"name": @"iPad (Gen. 1, WiFi)",     @"icon": @484 },
            @"iPad1,2":    @{ @"name": @"iPad (Gen. 1, GSM)",      @"icon": @484 },
            @"iPad2,1":    @{ @"name": @"iPad 2 (WiFi)",           @"icon": @504, @"icon;white": @505 },
            @"iPad2,2":    @{ @"name": @"iPad 2 (GSM)",            @"icon": @508, @"icon;white": @509 /* 504/505, 508/509 and 510/511 are identical pairs; how they relate to models is anyone's guess. */ },
            @"iPad2,3":    @{ @"name": @"iPad 2 (CDMA)",           @"icon": @510, @"icon;white": @511 },
            @"iPad2,4":    @{ @"name": @"iPad 2 (Rev A, WiFi)",    @"icon": @510, @"icon;white": @511 }, // Budget model with 32nm chip and better battry life
            @"iPad2,5":    @{ @"name": @"iPad mini (Gen. 1, WiFi)",@"icon": @536, @"icon;white": @537 },
            @"iPad2,6":    @{ @"name": @"iPad mini (Gen. 1, GSM)", @"icon": @538, @"icon;white": @539 },
            @"iPad2,7":    @{ @"name": @"iPad mini (Gen. 1, CDMA)",@"icon": @538, @"icon;white": @539 },
            @"iPad3,1":    @{ @"name": @"iPad (Gen. 3, WiFi)",     @"icon": @504, @"icon;white": @505 },
            @"iPad3,2":    @{ @"name": @"iPad (Gen. 3, CDMA)",     @"icon": @504, @"icon;white": @505 },
            @"iPad3,3":    @{ @"name": @"iPad (Gen. 3, GSM)",      @"icon": @504, @"icon;white": @505 },
            @"iPad3,4":    @{ @"name": @"iPad (Gen. 4, WiFi)",     @"icon": @504, @"icon;white": @505 },
            @"iPad3,5":    @{ @"name": @"iPad (Gen. 4, GSM)",      @"icon": @504, @"icon;white": @505 },
            @"iPad3,6":    @{ @"name": @"iPad (Gen. 4, CDMA)",     @"icon": @504, @"icon;white": @505 },

            // AppleTV1,1 runs Mac OS X
            @"AppleTV2,1": @{ @"name": @"AppleTV (Gen. 2)",        @"icon": @501 },
            @"AppleTV3,1": @{ @"name": @"AppleTV (Gen. 3)",        @"icon": @501 },
            @"AppleTV3,1": @{ @"name": @"AppleTV (Gen. 4, Rev A)", @"icon": @501 },
        };
    }

    return _infoDictionary;
}

@end
