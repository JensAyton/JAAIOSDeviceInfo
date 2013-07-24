#import "JAAAppDelegate.h"
#import "JAAIOSDeviceInfoManager.h"


@interface JAAAppDelegate ()

@property (weak) IBOutlet NSPopUpButton *devicePopup;
@property (weak) IBOutlet NSPopUpButton *colorPopup;

@property (weak) IBOutlet NSTextField *deviceIdentifierField;
@property (weak) IBOutlet NSImageView *iconImageView;

@property JAAIOSDeviceInfoManager *infoManager;

@end


@implementation JAAAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    self.infoManager = [JAAIOSDeviceInfoManager new];

    NSMenu *deviceMenu = [NSMenu new];
    for (NSString *deviceIdentifier in self.infoManager.knownDevices)
    {
        [deviceMenu addItem:[self menuItemForDeviceIdentifier:deviceIdentifier]];
    }
    [deviceMenu addItem:[NSMenuItem separatorItem]];
    [deviceMenu addItem:[self menuItemForDeviceIdentifier:@"x86_64"]];

    self.devicePopup.menu = deviceMenu;
    [self.devicePopup selectItemAtIndex:[self.devicePopup indexOfItemWithRepresentedObject:@"iPhone1,1"]];

    [self deviceSelected:nil];
}


- (NSMenuItem *)menuItemForDeviceIdentifier:(NSString *)deviceIdentifier
{
    NSString *title = [self.infoManager nameForDevice:deviceIdentifier];
    return [self menuItemWithTitle:title representedObject:deviceIdentifier];
}


- (NSMenuItem *)menuItemWithTitle:(NSString *)title representedObject:(id)representedObject
{
    NSMenuItem *item = [NSMenuItem new];
    item.title = title;
    item.representedObject = representedObject;
    return item;
}


- (IBAction)deviceSelected:(id)sender
{
    NSString *deviceIdentifier = self.devicePopup.selectedItem.representedObject;
    self.deviceIdentifierField.objectValue = deviceIdentifier;

    NSMenu *colorMenu = [NSMenu new];
    [colorMenu addItem:[self menuItemWithTitle:@"Default" representedObject:@""]];
    NSArray *colors = [self.infoManager knownColorsForDevice:deviceIdentifier];
    if (colors.count > 0)
    {
        [colorMenu addItem:[NSMenuItem separatorItem]];
        for (NSString *colorKey in colors)
        {
            [colorMenu addItem:[self menuItemWithTitle:[colorKey capitalizedString] representedObject:colorKey]];
        }
        self.colorPopup.enabled = YES;
    }
    else
    {
        self.colorPopup.enabled = NO;
    }
    self.colorPopup.menu = colorMenu;
    [self.colorPopup selectItemAtIndex:0];

    [self update];
}


- (IBAction)colorSelected:(id)sender
{
    [self update];
}


- (void) update
{
    NSString *deviceIdentifier = self.devicePopup.selectedItem.representedObject;
    NSString *colorKey = self.colorPopup.selectedItem.representedObject;

    self.iconImageView.objectValue = [self.infoManager iconForDevice:deviceIdentifier color:colorKey];
}

@end
