//
// Copyright (c) Zach Wily
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without modification, 
// are permitted provided that the following conditions are met:
// 
// - Redistributions of source code must retain the above copyright notice, this 
//     list of conditions and the following disclaimer.
// 
// - Redistributions in binary form must reproduce the above copyright notice, this
//     list of conditions and the following disclaimer in the documentation and/or 
//     other materials provided with the distribution.
// 
// - Neither the name of Zach Wily nor the names of its contributors may be used to 
//     endorse or promote products derived from this software without specific prior 
//     written permission.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
//   LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON 
//  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "iPhotoToGallery.h"
#import "ImageResizer.h"
#import "ZWAlbumNameFormatter.h"
#import "InterThreadMessaging.h"
#import "NSView+Fading.h"
#import "ZWGallery.h"
#import "ZWGalleryAlbum.h"
#import "ZWGalleryItem.h"

#include <Security/Security.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Growl/Growl.h>

@interface iPhotoToGallery (PrivateStuff)

- (int)addAlbumAndChildren:(ZWGalleryAlbum *)album toMenu:(NSMenu *)menu indentLevel:(int)level addSub:(BOOL)addSub;
- (void)openAddGalleryPanel;

@end

@implementation iPhotoToGallery

static int loggingIn;

#pragma mark -

- initWithExportImageObj:fp16 {
    [NSThread prepareForInterThreadMessages];
    
    exportManager = fp16; // weak reference - we don't expect our ExportManager to disappear on us

    [GrowlApplicationBridge setGrowlDelegate:self];
    
    preferences = [[NSMutableDictionary alloc] init];
    NSDictionary *userDefaultsPreferences = [[NSUserDefaults standardUserDefaults] persistentDomainForName:[[NSBundle bundleForClass:[self class]] bundleIdentifier]];
    if (userDefaultsPreferences) 
        [preferences addEntriesFromDictionary:userDefaultsPreferences];

    // build the galleries
    galleries = [[NSMutableArray alloc] init];
    NSArray *galleryDictionaries = [preferences objectForKey:@"galleries"];
    if ([galleryDictionaries isKindOfClass:[NSArray class]]) {
        NSEnumerator *each = [galleryDictionaries objectEnumerator];
        NSDictionary *galleryDictionary;
        while (galleryDictionary = [each nextObject]) {
            ZWGallery *gallery = [ZWGallery galleryWithDictionary:galleryDictionary];
            if (gallery) 
                [galleries addObject:gallery];
        }
    }

    return self;
}

- (void)dealloc {
    [preferences release];
    [galleries release];
    [super dealloc];
}

#pragma mark -
#pragma mark NSNibAwaking

- (void)awakeFromNib {
    // store initial size of advanced box
    if (!heightOfAdvancedBox) {
        NSRect advancedFrame = [gallerySettingsAdvancedBox frame];
        heightOfAdvancedBox = advancedFrame.size.height;
    }
    
    // remove the donate button if so desired
    if ([[preferences objectForKey:@"hideDonateButton"] boolValue]) {
        [mainDonateButton removeFromSuperview];
    }

    [self updateGalleryPopupMenu];
    
    // set the popup on the default gallery (if possible)
    if ([preferences objectForKey:@"defaultGallery"]) {
        if ([mainGalleryPopup indexOfItemWithTitle:[preferences objectForKey:@"defaultGallery"]] >= 0) 
            [mainGalleryPopup selectItemWithTitle:[preferences objectForKey:@"defaultGallery"]];
    }
    
    // set some user defined defaults
    if ([preferences objectForKey:@"openBrowser"])
        [mainOpenBrowserSwitch setState:[[preferences objectForKey:@"openBrowser"] intValue]];
    if ([preferences objectForKey:@"scaleImages"])
        [mainScaleImagesSwitch setState:[[preferences objectForKey:@"scaleImages"] intValue]];
    if ([preferences objectForKey:@"scaleImagesWidth"])
        [mainScaleImagesWidthField setIntValue:[[preferences objectForKey:@"scaleImagesWidth"] intValue]];
    if ([preferences objectForKey:@"scaleImagesHeight"])
        [mainScaleImagesHeightField setIntValue:[[preferences objectForKey:@"scaleImagesHeight"] intValue]];
    if ([preferences objectForKey:@"exportComments"])
        [mainExportCommentsSwitch setState:[[preferences objectForKey:@"exportComments"] intValue]];
    
    // if this is their first time, pop down the "add gallery" sheet
    if ([galleries count] == 0 && ![[preferences objectForKey:@"offeredToCreateGalleryOnFirstOpen"] boolValue]) {
        [preferences setObject:[NSNumber numberWithBool:YES] forKey:@"offeredToCreateGalleryOnFirstOpen"];
        [self savePreferences];
        
        // We need to wait until the export window is on the screen before trying to pop the sheet down...
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(exportWindowDidBecomeKey:)
                                                     name:NSWindowDidBecomeKeyNotification
                                                   object:nil];
    }
}

#pragma mark -
#pragma mark ExportPluginProtocol

- (NSString *)description {
    return @"iPhotoToGallery Exporter by Zach Wily";
}

- (NSString *)name {
    return @"iPhotoToGallery";
}

- (void)cancelExport {

}

- (void)unlockProgress {

}

- (void)lockProgress {

}

- (void *)progress {
    return NULL;
}

- (void)performExport:fp16 {

}

- (void)startExport:fp16 {
    // save the defaults
    [preferences setObject:[NSNumber numberWithBool:[mainScaleImagesSwitch state]] forKey:@"scaleImages"];
    if ([mainScaleImagesSwitch state] == NSOnState) {
        [preferences setObject:[NSNumber numberWithInt:[mainScaleImagesWidthField intValue]] forKey:@"scaleImagesWidth"];
        [preferences setObject:[NSNumber numberWithInt:[mainScaleImagesHeightField intValue]] forKey:@"scaleImagesHeight"];
    }
    [preferences setObject:[NSNumber numberWithBool:[mainOpenBrowserSwitch state]] forKey:@"openBrowser"];
    [preferences setObject:[NSNumber numberWithBool:[mainExportCommentsSwitch state]] forKey:@"exportComments"];
    [self savePreferences];

    [progressUploadingTextField setStringValue:@"Starting Export..."];
    [progressUploadingDetailField setStringValue:@""];
    [progressProgressIndicator setMinValue:0.0];
    [progressProgressIndicator setMaxValue:(double)([exportManager imageCount])];
    [progressProgressIndicator setDoubleValue:0.0];
    [progressProgressIndicator setUsesThreadedAnimation:YES];
    [progressProgressIndicator startAnimation:self];
    [progressImageView setImage:nil];
    
    [NSThread detachNewThreadSelector:@selector(addItemsThread:) toTarget:self withObject:self];
    [NSApp beginSheet:progressPanel modalForWindow:[exportManager window] modalDelegate:self didEndSelector:@selector(progressSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)progressSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{    
    [progressProgressIndicator stopAnimation:self];
    [sheet orderOut:self];
}

- (void)clickExport {

}

- (char)validateUserCreatedPath:fp16 {
    return NO;
}

- (char)treatSingleSelectionDifferently {
    return NO;
}

- (NSString *)defaultDirectory {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"];
}

- (NSString *)defaultFileName {
    return @"test";
}

- (NSString *)getDestinationPath {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"];
}

- (char)wantsDestinationPrompt {
    return NO;
}

- (id)requiredFileType {
    return @"album";
}

- (void)viewWillBeDeactivated {
    if ((currentGallery != nil) && ([currentGallery loggedIn])) {
        [currentGallery logout];
        [self setLoggedInOut];
    }
}

- (void)viewWillBeActivated {
    // logout if we're logged in (we shouldn't be)
    if ((currentGallery != nil) && ([currentGallery loggedIn])) {
        [currentGallery logout];
    }
    
    [self setLoggedInOut];
    
    // attempt to login
    if (!loggingIn) {
        loggingIn = 1;
        [self loginToSelectedGallery];
    }
}

- (id)lastView {
    return lastView;
}

- (id)firstView {
    return firstView;
}

- (id)settingsView {
    return settingsView;
}

#pragma mark -
#pragma mark IBActions

#pragma mark - Main Window

- (IBAction)clickGalleryPopup:(id)sender {
    if ([mainGalleryPopup indexOfSelectedItem] == [mainGalleryPopup numberOfItems] - 1) {
        // open the Edit Gallery List sheet
        [galleryListTable reloadData];
        [NSApp beginSheet:galleryListPanel modalForWindow:[exportManager window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    }
    else if ([mainGalleryPopup indexOfSelectedItem] == [mainGalleryPopup numberOfItems] - 2) {
        // open the Add Gallery sheet
        [self openAddGalleryPanel];
    }
    else {
        indexOfLastGallery = [mainGalleryPopup indexOfSelectedItem];
        if (![[[mainGalleryPopup selectedItem] title] isEqual:@"(None)"]) {
            [self loginToSelectedGallery];
            
            [preferences setObject:[currentGallery identifier] forKey:@"defaultGallery"];
            [self savePreferences];
        }
    }
}

- (IBAction)clickLogin:(id)sender {
    
}

- (IBAction)clickCancelLogin:(id)sender {
    [currentGallery cancelOperation];
}

- (IBAction)clickCreateNewAlbum:(id)sender {
    // set the ZWAlbumNameFormatter on the album name field
    if (![albumSettingsNameField formatter]) {
        ZWAlbumNameFormatter *nameFormatter = [[ZWAlbumNameFormatter alloc] init];
        [albumSettingsNameField setFormatter:nameFormatter];
        [nameFormatter release];
    }
    
    [albumSettingsPanel makeFirstResponder:albumSettingsTitleField];
    [albumSettingsTitleField setStringValue:@""];
    [albumSettingsNameField setStringValue:@""];
    [albumSettingsDescriptionField setString:@""];
    
    // populate the "nested in" popup
    [albumSettingsNestedInPopup removeAllItems];
    [albumSettingsNestedInPopup setAutoenablesItems:NO];
	if (![currentGallery isGalleryV2])
		[albumSettingsNestedInPopup addItemWithTitle:@"(None)"];
    
	int count = 0;
	NSEnumerator *enumerator = [[currentGallery albums] objectEnumerator];
	ZWGalleryAlbum *album;
	while (album = [enumerator nextObject]) {
		if ([album canAddSubToAlbumOrSub] && ![album parent]) 
			count += [self addAlbumAndChildren:album toMenu:[albumSettingsNestedInPopup menu] indentLevel:0 addSub:YES];
	}
    
    if (count) 
        [albumSettingsNestedInPopup setEnabled:YES];
    else 
        [albumSettingsNestedInPopup setEnabled:NO];
    
    // start the "nested in" popup on the currently selected gallery, if possible
    // This is only relevant for G2 - for G1 we will default to an album at root level
    if ([currentGallery isGalleryV2]) {
        ZWGalleryAlbum *selectedAlbum = [[mainAddToAlbumPopup selectedItem] representedObject];
        int idx = [albumSettingsNestedInPopup indexOfItemWithRepresentedObject:selectedAlbum];
        if (idx >= 0 && [[albumSettingsNestedInPopup itemAtIndex:idx] isEnabled]) 
            [albumSettingsNestedInPopup selectItemAtIndex:idx];
    }
    
    [NSApp beginSheet:albumSettingsPanel modalForWindow:[exportManager window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
}

- (IBAction)clickScaleImages:(id)sender {
    [self setScaleImages];
}

- (IBAction)clickiPhotoToGalleryName:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://zwily.com/iphoto"]];
}

- (IBAction)clickDonate:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://zwily.com/iphoto/donate.html"]];
}

#pragma mark - Add Gallery Panel

- (IBAction)clickGallerySettingsOK:(id)sender {
    NSString *urlString = [gallerySettingsURLField stringValue];
    NSString *username = [gallerySettingsUsernameField stringValue];
    NSString *password = [gallerySettingsPasswordField stringValue];
    NSString *httpuser = [gallerySettingsHTTPUsernameField stringValue];
    NSString *httppass = [gallerySettingsHTTPPasswordField stringValue];
    
    // do URL munging here
    NSString *scheme;
    NSMutableString *tmpURLString = [NSMutableString stringWithString:urlString];
    if ([tmpURLString hasPrefix:@"http://"]) {
        [tmpURLString deleteCharactersInRange:NSMakeRange(0, 7)];
        if ([gallerySettingsUseHTTPSSwitch state] == NSOnState) 
            scheme = @"https://";
        else 
            scheme = @"http://";
    } else if ([tmpURLString hasPrefix:@"https://"]) {
        [tmpURLString deleteCharactersInRange:NSMakeRange(0, 8)];
        scheme = @"https://";
    } else if ([gallerySettingsUseHTTPSSwitch state] == NSOnState) {
        scheme = @"https://";
    } else {
        scheme = @"http://";
    }
    
    if (![tmpURLString hasSuffix:@"/"]) 
        [tmpURLString appendString:@"/"];
    
    NSMutableString *buildURLString = [NSMutableString string];
    // first the scheme
    [buildURLString appendString:scheme];
    // http auth options (if specified)
    if ([gallerySettingsUseHTTPAuthSwitch state] == NSOnState) {
        [buildURLString appendString:httpuser];
        [buildURLString appendString:@":"];
        [buildURLString appendString:httppass];
        [buildURLString appendString:@"@"];
    }
    // add the rest
    [buildURLString appendString:tmpURLString];
    
    NSURL *url = [NSURL URLWithString:buildURLString];
    
    if ([urlString isEqual:@""]) {
        NSRunAlertPanel(@"URL Missing",
                        @"Please enter the URL for your gallery installation",
                        @"OK",
                        nil,
                        nil);
        return;
    }
    
    if (url == nil) {
        NSRunAlertPanel(@"Invalid URL",
                        [NSString stringWithFormat:@"The URL '%@' is invalid.", buildURLString], 
                        @"OK",
                        nil,
                        nil);
        return;
    }
    
    ZWGallery *gallery = [ZWGallery galleryWithURL:url username:username];
    if (gallery) {
        [galleries addObject:gallery];
        [self savePreferences];
        [self updateGalleryPopupMenu];
        
        // add password to the keychain
        NSString *host = [[gallery url] host];
        NSString *path = [[gallery url] path];
        OSStatus status = SecKeychainAddInternetPassword(NULL,
                                                         strlen([host UTF8String]),
                                                         [host UTF8String],
                                                         0,
                                                         NULL,
                                                         strlen([username UTF8String]),
                                                         [username UTF8String],
                                                         strlen([path UTF8String]),
                                                         [path UTF8String],
                                                         80,
                                                         kSecProtocolTypeHTTP,
                                                         kSecAuthenticationTypeDefault,
                                                         strlen([password UTF8String]),
                                                         [password UTF8String],
                                                         NULL);
        
        // TODO: check that add succeeded
        if (status != noErr) 
            NSLog(@"iPhotoToGallery: Error adding password to keychain: %i", status);
        
        [mainGalleryPopup selectItemWithTitle:[gallery identifier]];
        [self clickGalleryPopup:self];
    }
    
    [NSApp endSheet:gallerySettingsPanel];
}

- (IBAction)clickGallerySettingsShowAdvancedOptions:(id)sender {
    [self updateGallerySettingsAdvancedOptions];
}

- (IBAction)clickGallerySettingsUseHTTPAuth:(id)sender {
    [self updateGallerySettingsHTTPAuthOptionsUpdate];
}

- (IBAction)clickGallerySettingsCancel:(id)sender {
    [mainGalleryPopup selectItemAtIndex:indexOfLastGallery];
    
    [NSApp endSheet:gallerySettingsPanel];
}

#pragma mark - Gallery List Panel

- (IBAction)clickGalleryListDone:(id)sender {
    if ([galleries count] == 0) {
        [mainGalleryPopup selectItemAtIndex:0];
        currentGallery = nil;
        [self setLoggedInOut];
    } else if (!lastGallerySelected) {
        [mainGalleryPopup selectItemAtIndex:0];
    } else if ([mainGalleryPopup indexOfItemWithTitle:lastGallerySelected] >= 0) {
        // the last selected gallery still exists
        [mainGalleryPopup selectItemWithTitle:lastGallerySelected];
    } else if ([mainGalleryPopup indexOfItemWithTitle:lastGallerySelected] == -1) {
        // previously selected gallery is gone
        [mainGalleryPopup selectItemAtIndex:0];
        [self clickGalleryPopup:self];
    }
    
    [NSApp endSheet:galleryListPanel];
}

- (IBAction)clickGalleryListRemove:(id)sender {
    ZWGallery *gallery = [galleries objectAtIndex:[galleryListTable selectedRow]];
    NSString *username = [gallery username];
    NSString *host = [[gallery url] host];
    NSString *path = [[gallery url] path];
    
    SecKeychainItemRef item = NULL;
    
    OSStatus status =
        SecKeychainFindInternetPassword (NULL,
                                         strlen([host UTF8String]),
                                         [host UTF8String],
                                         0,
                                         NULL,
                                         strlen([username UTF8String]),
                                         [username UTF8String],
                                         strlen([path UTF8String]),
                                         [path UTF8String],
                                         80,
                                         kSecProtocolTypeHTTP,
                                         kSecAuthenticationTypeDefault,
                                         NULL,
                                         NULL,
                                         &item);
    
    // TODO: Make sure this succeeded. Then again, so what if it doesn't?
    
    if (item) {
        status = SecKeychainItemDelete(item);
        CFRelease(item);
    }
    
    [galleries removeObjectAtIndex:[galleryListTable selectedRow]];
    [self savePreferences];
    
    [self updateGalleryPopupMenu];
    [galleryListTable reloadData];
}

- (IBAction)clickGalleryListSelectGallery:(id)sender {
    if ([galleryListTable selectedRow] != -1) 
        [galleryListRemoveGalleryButton setEnabled:TRUE];
    else
        [galleryListRemoveGalleryButton setEnabled:FALSE];
}

#pragma mark - Create Album Panel

- (IBAction)clickAlbumSettingsCreateAlbum:(id)sender {
    [mainProgressIndicator startAnimation:self];
    [mainStatusString setStringValue:@"Creating album..."];
    
    [currentGallery createAlbumWithName:[albumSettingsNameField stringValue]
                                  title:[albumSettingsTitleField stringValue]
                                summary:[albumSettingsDescriptionField string]
                                 parent:[[albumSettingsNestedInPopup selectedItem] representedObject]];
    
    [NSApp endSheet:albumSettingsPanel];
}

- (IBAction)clickAlbumSettingsCancel:(id)sender {
    [NSApp endSheet:albumSettingsPanel];
}

#pragma mark - Password Panel

- (IBAction)clickPasswordOK:(id)sender
{
    
}

- (IBAction)clickPasswordCancel:(id)sender
{
    
}

#pragma mark - Progress Panel

- (IBAction)clickProgressCancel:(id)sender
{
    [currentAlbum cancelOperation];
}

#pragma mark -
#pragma mark Notifications

- (void)exportWindowDidBecomeKey:(NSNotification *)note
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self openAddGalleryPanel];
}

#pragma mark -

- (void)openAddGalleryPanel
{
    [gallerySettingsHTTPPasswordField setStringValue:@""];
    [gallerySettingsHTTPUsernameField setStringValue:@""];
    [gallerySettingsPasswordField setStringValue:@""];
    [gallerySettingsURLField setStringValue:@""];
    [gallerySettingsUsernameField setStringValue:@""];
    [gallerySettingsUseHTTPAuthSwitch setState:NSOffState];
    [gallerySettingsUseHTTPSSwitch setState:NSOffState];
    
    [gallerySettingsPanel makeFirstResponder:gallerySettingsURLField];
    
    [self updateGallerySettingsHTTPAuthOptionsUpdate];
    
    // make sure the advanced box is closed
    if ([gallerySettingsShowAdvancedOptionsSwitch state] == NSOnState) {
        [gallerySettingsShowAdvancedOptionsSwitch setState:NSOffState];
        [self updateGallerySettingsAdvancedOptions];    
    }
    
    [NSApp beginSheet:gallerySettingsPanel 
       modalForWindow:[exportManager window] 
        modalDelegate:self 
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
          contextInfo:NULL];
}

- (id)exportManager {
    return exportManager;
}

- (void)showCancelButton:(NSTimer *)timer
{
    showCancelTimer = nil;
    
    [mainConnectCancelButton setHiddenWithFade:NO];
}

- (void)hideCancelButton
{
    [showCancelTimer invalidate];
    showCancelTimer = nil;

    [mainConnectCancelButton setHiddenWithFade:YES];    
}

- (void)loginToSelectedGallery
{
    if (![[[mainGalleryPopup selectedItem] title] isEqual:@"(None)"]) {
        
        // logout if we're logged in
        if ((currentGallery != nil) && ([currentGallery loggedIn])) {
            [currentGallery logout];
            [self setLoggedInOut];
        }
        currentGallery = [[mainGalleryPopup selectedItem] representedObject];
        [lastGallerySelected release];
        lastGallerySelected = [[mainGalleryPopup titleOfSelectedItem] retain];
        // attempt to login
        if (![currentGallery loggedIn] && currentGallery) {
            [currentGallery setPassword:[self lookupPasswordForCurrentGallery]];
            [currentGallery setDelegate:self];
            [mainProgressIndicator startAnimation:self];
            [mainStatusString setStringValue:@"Logging in..."];
            [mainGalleryPopup setEnabled:FALSE];
            
            [currentGallery login];
            
            showCancelTimer = [NSTimer timerWithTimeInterval:0.5
                                                      target:self
                                                    selector:@selector(showCancelButton:)
                                                    userInfo:nil
                                                     repeats:NO];
            [[NSRunLoop currentRunLoop] addTimer:showCancelTimer forMode:NSModalPanelRunLoopMode];
        }
    }
}

- (void)updateGalleryPopupMenu {
    [mainGalleryPopup removeAllItems];
    // sort the galleries (TODO: mem problem? sortedgalleries is returned auto-released, right?)
    NSArray *sortedGalleries = [galleries sortedArrayUsingSelector:@selector(compare:)];
    
    // add them to the menu
    NSEnumerator *enumerator = [sortedGalleries objectEnumerator];
    id gallery;
    while (gallery = [enumerator nextObject]) {
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[gallery identifier] action:nil keyEquivalent:@""];
        [menuItem setRepresentedObject:gallery];
        [[mainGalleryPopup menu] addItem:menuItem];
    }
    
    if ([galleries count] == 0) {
        [mainGalleryPopup addItemWithTitle:@"(None)"];
        [mainStatusString setStringValue:@"No galleries configured"];
    }
    
    // add separator
    [[mainGalleryPopup menu] addItem:[NSMenuItem separatorItem]];
    
    // add Add Gallery... and Edit List... options
    [mainGalleryPopup addItemWithTitle:@"Add Gallery..."];
    [mainGalleryPopup addItemWithTitle:@"Edit Gallery List..."];
    
    // fix selection
    [mainGalleryPopup selectItemAtIndex:0];
}

- (void)updateGallerySettingsAdvancedOptions {
    NSRect winFrame = [gallerySettingsPanel frame];
    NSRect advancedFrame = [gallerySettingsAdvancedBox frame];
    
    if ([gallerySettingsShowAdvancedOptionsSwitch state] == NSOffState) {
        [gallerySettingsShowAdvancedOptionsString setStringValue:@"Show advanced options"];
        
        winFrame.size.height -= heightOfAdvancedBox;
        winFrame.origin.y += heightOfAdvancedBox;
        advancedFrame.size.height = 0;
    } else {
        [gallerySettingsShowAdvancedOptionsString setStringValue:@"Hide advanced options"];
        
        winFrame.size.height += heightOfAdvancedBox;
        winFrame.origin.y -= heightOfAdvancedBox;
        advancedFrame.size.height = heightOfAdvancedBox;
    }
    
    // resize the window and advanced box
    [gallerySettingsPanel setFrame:winFrame display:YES animate:YES];
    [gallerySettingsAdvancedBox setFrame:advancedFrame];
}    

- (void)updateGallerySettingsHTTPAuthOptionsUpdate {
    if ([gallerySettingsUseHTTPAuthSwitch state] == NSOnState) {
        [gallerySettingsHTTPUsernameField setEnabled:TRUE];
        [gallerySettingsHTTPPasswordField setEnabled:TRUE];
    } else {
        [gallerySettingsHTTPUsernameField setEnabled:FALSE];
        [gallerySettingsHTTPPasswordField setEnabled:FALSE];
    }
}

- (void)savePreferences {
    NSMutableArray *galleriesPrefs = [[NSMutableArray array] retain];
    
    NSEnumerator *enumerator = [galleries objectEnumerator];
    id gallery;
    while (gallery = [enumerator nextObject]) 
        [galleriesPrefs addObject:[gallery infoDictionary]];
    [preferences setObject:galleriesPrefs forKey:@"galleries"];
    
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [[NSUserDefaults standardUserDefaults] setPersistentDomain:preferences forName:[[NSBundle bundleForClass:[self class]] bundleIdentifier]];
    
    [galleriesPrefs release];
}

// This is a little helper method that populates those album menus. You hand it an album and it recursively adds it
// and sub-albums, increasing indentation as you get further down the tree. The confusingly-named "addSub" lets you specify
// whether or not to only add sub-albums that the user has permission to create a new album in. Or something like that. :)
- (int)addAlbumAndChildren:(ZWGalleryAlbum *)album toMenu:(NSMenu *)menu indentLevel:(int)level addSub:(BOOL)addSub
{
	int count = 0;

	NSMenuItem *albumMenuItem = [[[NSMenuItem alloc] initWithTitle:[album title] action:nil keyEquivalent:@""] autorelease];
    [albumMenuItem setIndentationLevel:level];
	[albumMenuItem setRepresentedObject:album];
	if (!addSub && ![album canAddItem]) 
		[albumMenuItem setEnabled:FALSE];
	else if (addSub && ![album canAddSubAlbum])
		[albumMenuItem setEnabled:FALSE];
	else
		[albumMenuItem setEnabled:TRUE];
	[menu addItem:albumMenuItem];
	count++;
	
	NSEnumerator *each = [[album children] objectEnumerator];
	ZWGalleryAlbum *child;
	while (child = [each nextObject]) {
		if (!addSub && [child canAddItemToAlbumOrSub]) 
			count += [self addAlbumAndChildren:child toMenu:menu indentLevel:(level + 1) addSub:addSub];
		else if (addSub && [child canAddSubToAlbumOrSub]) 
			count += [self addAlbumAndChildren:child toMenu:menu indentLevel:(level + 1) addSub:addSub];
	}
	
	return count;
}

- (void)updateAlbumPopupMenu {
    NSArray *albums = [currentGallery albums];
    [mainAddToAlbumPopup removeAllItems];
    if (albums == nil) {
        return;
    }
    int anyAlbums = 0;
    
    [mainAddToAlbumPopup setAutoenablesItems:NO];
    
	NSEnumerator *enumerator = [albums objectEnumerator];
	ZWGalleryAlbum *album;
	while (album = [enumerator nextObject]) {
		if ([album canAddItemToAlbumOrSub] && ![album parent]) {
			anyAlbums += [self addAlbumAndChildren:album toMenu:[mainAddToAlbumPopup menu] indentLevel:0 addSub:NO];
		}
	}
	
    if (!anyAlbums) {
        [mainAddToAlbumPopup addItemWithTitle:@"(None)"];
        [mainAddToAlbumPopup setEnabled:FALSE];
        [exportManager disableControls];
    } else {
        [mainAddToAlbumPopup setEnabled:TRUE];
        [exportManager enableControls];
        
        // make sure a disabled item isn't selected
        while (![[mainAddToAlbumPopup selectedItem] isEnabled]) {
            [mainAddToAlbumPopup selectItemAtIndex:([mainAddToAlbumPopup indexOfSelectedItem] + 1)];
        }
        
    }
    
}

- (void)setLoggedInOut {
    if ([currentGallery loggedIn]) {
        [exportManager enableControls];
        
        [mainCreateNewAlbumButton setEnabled:TRUE];
        [mainOpenBrowserSwitch setEnabled:TRUE];
        [mainScaleImagesSwitch setEnabled:TRUE];
        [self setScaleImages];
        [mainExportCommentsSwitch setEnabled:TRUE];
    } else {
        [exportManager disableControls];
        
        [mainAddToAlbumPopup removeAllItems];
        [mainAddToAlbumPopup setEnabled:FALSE];
        [mainCreateNewAlbumButton setEnabled:FALSE];
        [mainOpenBrowserSwitch setEnabled:FALSE];
        [mainScaleImagesSwitch setEnabled:FALSE];
        [mainScaleImagesHeightField setEnabled:FALSE];
        [mainScaleImagesWidthField setEnabled:FALSE];
        [mainExportCommentsSwitch setEnabled:FALSE];
    }
}

- (void)setScaleImages {
    if ([mainScaleImagesSwitch state] == NSOnState) {
        [mainScaleImagesHeightField setEnabled:TRUE];
        [mainScaleImagesWidthField setEnabled:TRUE];
    } else {
        [mainScaleImagesHeightField setEnabled:FALSE];
        [mainScaleImagesWidthField setEnabled:FALSE];
    }
}

// This is a little method to make iPhoto 5 compatibility a little easier. (iPhoto 5 removed the imageDictionaryAtIndex: method)
- (NSDictionary *)exportManagerImageDictionaryAtIndex:(int)index
{
    if ([exportManager respondsToSelector:@selector(imageDictionaryAtIndex:)])
        return [exportManager imageDictionaryAtIndex:index];
    
    NSMutableDictionary *imageDict = [NSMutableDictionary dictionary];
    if ([exportManager respondsToSelector:@selector(imageCaptionAtIndex:)])
        [imageDict setObject:[exportManager imageCaptionAtIndex:index] forKey:@"Caption"];
    
    if ([exportManager respondsToSelector:@selector(imageCommentsAtIndex:)])
        [imageDict setObject:[exportManager imageCommentsAtIndex:index] forKey:@"Annotation"];
    
    return imageDict;
}

- (NSString*)lookupPasswordForCurrentGallery {
    if (currentGallery == nil) 
        return nil;
    NSString *username = [currentGallery username];
    NSString *host = [[currentGallery url] host];
    NSString *path = [[currentGallery url] path];
    
    UInt32 passwordLength;
    void *passwordData;
    
    OSStatus status =
        SecKeychainFindInternetPassword (NULL,
                                         strlen([host UTF8String]),
                                         [host UTF8String],
                                         0,
                                         NULL,
                                         strlen([username UTF8String]),
                                         [username UTF8String],
                                         strlen([path UTF8String]),
                                         [path UTF8String],
                                         80,
                                         kSecProtocolTypeHTTP,
                                         kSecAuthenticationTypeDefault,
                                         &passwordLength,
                                         &passwordData,
                                         NULL);
    if (status != noErr) {
        // TODO: Pop up password dialog here.
        NSLog(@"iPhotoToGallery: Error retrieving password from keychain: %i", (int)status);
        return nil;
    }
    
    NSString *password = [NSString stringWithCString:passwordData length:passwordLength];
    if (passwordLength) 
        SecKeychainItemFreeContent(NULL, passwordData);

    return password;
}

// This method is always called in the main thread and updates the UI of the progress sheet
- (void)updateProgress:(NSDictionary *)progressInfo
{
    if ([progressInfo objectForKey:@"UploadingTextField"])
        [progressUploadingTextField setStringValue:[progressInfo objectForKey:@"UploadingTextField"]];
    
    if ([progressInfo objectForKey:@"UploadingDetailField"])
        [progressUploadingDetailField setStringValue:[progressInfo objectForKey:@"UploadingDetailField"]];
    
    if ([progressInfo objectForKey:@"ProgressBarLocation"])
        [progressProgressIndicator setDoubleValue:[[progressInfo objectForKey:@"ProgressBarLocation"] doubleValue]];
    
    if ([progressInfo objectForKey:@"Image"])
        [progressImageView setImage:[progressInfo objectForKey:@"Image"]];
}

#pragma mark -
#pragma mark Threads

- (void)addItemsThread:(id)target
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    [NSThread prepareForInterThreadMessages];
    
    // this is the thread that uploads all the images
    ZWGalleryAlbum *album = [[mainAddToAlbumPopup selectedItem] representedObject];
    if (album == nil) 
        return;
    
    currentAlbum = album;
    ZWGalleryRemoteStatusCode status = 0;
    
    int imageNum;
    BOOL cancel = NO;
    for (imageNum = 0; imageNum < (int)[exportManager imageCount] && !cancel; imageNum++) {
        // Create our own pool so we don't use up tons of memory with autoreleased image data
        NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init]; {
        
            NSString *imagePath = [exportManager imagePathAtIndex:imageNum];
            NSDictionary *imageDict = [self exportManagerImageDictionaryAtIndex:imageNum];
            
            ZWGalleryItem *item = [ZWGalleryItem itemWithAlbum:album];
            
            // add the filename
            [item setFilename:[imagePath lastPathComponent]];
            
            // add the image type (default to jpg)
            // TODO: Be smarter here. There are many more possible image types we need to handle.
            if ([[imagePath pathExtension] caseInsensitiveCompare:@"gif"] == NSOrderedSame) 
                [item setImageType:@"image/gif"];
            else if ([[imagePath pathExtension] caseInsensitiveCompare:@"png"] == NSOrderedSame) 
                [item setImageType:@"image/png"];
            else 
                [item setImageType:@"image/jpeg"];
            
            // add the comments and description, if so desired
            if ([mainExportCommentsSwitch state]) {
                if ([imageDict objectForKey:@"Caption"]) 
                    [item setCaption:[imageDict objectForKey:@"Caption"]];
                if ([imageDict objectForKey:@"Annotation"]) 
                    [item setDescription:[imageDict objectForKey:@"Annotation"]];
            }
            
            // finally, add the image data
            NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
            NSImage *image = [[[NSImage alloc] initWithData:imageData] autorelease];

            currentImageIndex = imageNum;
            
            if ([mainScaleImagesSwitch state] == NSOnState) {
                NSDictionary *progressInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                    [NSString stringWithFormat:@"Resizing %@...", [imagePath lastPathComponent]], @"UploadingTextField",
                    [NSString stringWithFormat:@"(Photo %i of %i)", imageNum + 1, (int)[exportManager imageCount]], @"UploadingDetailField",
                    [NSNumber numberWithInt:currentImageIndex], @"ProgressBarLocation",
                    image, @"Image",
                    nil];
                [self performSelectorOnMainThread:@selector(updateProgress:) withObject:progressInfo waitUntilDone:NO modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];
                
                NSData *scaledData = [ImageResizer getScaledImageFromData:imageData toSize:NSMakeSize([mainScaleImagesWidthField intValue], [mainScaleImagesHeightField intValue])];
                [item setData:scaledData];
                currentImageSize = [scaledData length];
            } else {
                [item setData:imageData];
                currentImageSize = [imageData length];
            }

            NSDictionary *progressInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSString stringWithFormat:@"Uploading %@...", [imagePath lastPathComponent]], @"UploadingTextField",
                [NSString stringWithFormat:@"(Photo %i of %i)", imageNum + 1, (int)[exportManager imageCount]], @"UploadingDetailField",
                [NSNumber numberWithInt:currentImageIndex], @"ProgressBarLocation",
                image, @"Image",
                nil];
            [self performSelectorOnMainThread:@selector(updateProgress:) withObject:progressInfo waitUntilDone:NO modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];
            
            [album setDelegate:self];
            status = [album addItemSynchronously:item];

            if (status != GR_STAT_SUCCESS) {
                switch (status) {
                    case ZW_GALLERY_OPERATION_DID_CANCEL:
                        if (imageNum == 1) 
                            [mainStatusString setStringValue:[NSString stringWithFormat:@"Export cancelled after %i photo", imageNum]];
                        else
                            [mainStatusString setStringValue:[NSString stringWithFormat:@"Export cancelled after %i photos", imageNum]];
                        break;
                    
                    case GR_STAT_UPLOAD_PHOTO_FAIL:
                        [mainStatusString setStringValue:@"Failed. Could not upload."];
                        break;

                    default:
                        NSLog(@"Export failed with error: %i", status);
                        [mainStatusString setStringValue:[NSString stringWithFormat:@"Export failed (error code: %i)", status]];
                }
                    
                if (status != ZW_GALLERY_OPERATION_DID_CANCEL) {
                    [GrowlApplicationBridge notifyWithTitle:@"Export Failed"
                                                description:[NSString stringWithFormat:@"Export to gallery failed after %i photos were uploaded",
                                                    imageNum]
                                           notificationName:@"Export to Gallery Failed"
                                                   iconData:[item data]
                                                   priority:0
                                                   isSticky:NO
                                               clickContext:NULL];
                }
                
                cancel = YES;
            }
            else {
                [GrowlApplicationBridge notifyWithTitle:@"Photo Uploaded"
                                            description:[NSString stringWithFormat:@"Photo %@ uploaded to Gallery",
                                                [item filename]]
                                       notificationName:@"Photo Uploaded to Gallery"
                                               iconData:[item data]
                                               priority:0
                                               isSticky:NO
                                           clickContext:NULL];
            }
            
        } [innerPool release];
    }
    
    [NSApp endSheet:progressPanel];
    
    if (status == GR_STAT_SUCCESS) {
        if ([mainOpenBrowserSwitch state] == NSOnState) {
            NSMutableString *albumURLString = nil;
            
            if (![currentGallery isGalleryV2]) {
                albumURLString = [NSMutableString stringWithString:[[currentGallery url] absoluteString]];
                [albumURLString appendString:[album name]];
            }
            else {
                // URLs look like this: http://example.com/gallery2/main.php?g2_view=core:ShowItem&g2_itemId=16
                albumURLString = [NSMutableString stringWithString:[[currentGallery url] absoluteString]];
                [albumURLString appendFormat:@"/main.php?g2_view=core:ShowItem&g2_itemId=%@", [album name]];
            }
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:albumURLString]];
        }

        [GrowlApplicationBridge notifyWithTitle:@"All Photos Uploaded"
                                    description:[NSString stringWithFormat:@"%i photos were uploaded to Gallery",
                                        [exportManager imageCount]]
                               notificationName:@"All Photos Uploaded to Gallery"
                                       iconData:nil
                                       priority:0
                                       isSticky:NO
                                   clickContext:NULL];
        
        [exportManager cancelExportBeforeBeginning];
    }
        
    currentAlbum = nil;
        
    [pool release];
}

#pragma mark -
#pragma mark ZWGalleryDelegate

- (void)galleryDidLogin:(ZWGallery *)sender
{
    [mainStatusString setStringValue:@"Fetching albums..."];
    [currentGallery getAlbums];
    
    [mainGalleryPopup setEnabled:TRUE];
    loggingIn = 0;
}

- (void)gallery:(ZWGallery *)sender loginFailedWithCode:(NSNumber *)statusNumber
{
    [self hideCancelButton];
    
    ZWGalleryRemoteStatusCode status = [statusNumber intValue];
    if (status == GR_STAT_PASSWD_WRONG) {
        [mainProgressIndicator stopAnimation:self];
        [mainStatusString setStringValue:@"Bad username/password"];
        [self setLoggedInOut];
        // TODO: Pop up password dialog here.
    }
    else if (status == ZW_GALLERY_COULD_NOT_CONNECT) {
        [mainProgressIndicator stopAnimation:self];
        [mainStatusString setStringValue:@"Could not connect to the gallery"];
        [self setLoggedInOut];
    }
    else if (status == ZW_GALLERY_PROTOCOL_ERROR) {
        [mainProgressIndicator stopAnimation:self];
        [mainStatusString setStringValue:@"No gallery found at URL"];
        [self setLoggedInOut];
    }
    else if (status == ZW_GALLERY_OPERATION_DID_CANCEL) {
        [mainProgressIndicator stopAnimation:self];
        [mainStatusString setStringValue:@"Login cancelled"];
        [self setLoggedInOut];
    }
    else {
        [mainProgressIndicator stopAnimation:self];
        [mainStatusString setStringValue:[NSString stringWithFormat:@"Unknown error: %i", (int)status]];
        [self setLoggedInOut];
    }
    
    [mainGalleryPopup setEnabled:TRUE];
    loggingIn = 0;    
}

- (void)galleryDidGetAlbums:(ZWGallery *)sender
{
    [self hideCancelButton];
    
    [mainProgressIndicator stopAnimation:self];

    [mainStatusString setStringValue:@"Logged in"];

    [self updateAlbumPopupMenu];
    [self setLoggedInOut];
    
    if (selectLastCreatedAlbumWhenDoneFetching) {
        selectLastCreatedAlbumWhenDoneFetching = NO;
        
        NSString *newAlbumName = [currentGallery lastCreatedAlbumName];
        
        int i;
        for (i = 0; i < [mainAddToAlbumPopup numberOfItems]; i++) {
            id<NSMenuItem> item = [mainAddToAlbumPopup itemAtIndex:i];
            if ([[item representedObject] respondsToSelector:@selector(name)] &&
                [[[item representedObject] name] isEqual:newAlbumName]) {
                [mainAddToAlbumPopup selectItemAtIndex:i];
                break;
            }            
        }
    }
}

- (void)gallery:(ZWGallery *)sender getAlbumsFailedWithCode:(NSNumber *)statusNumber
{
    [self hideCancelButton];
    
    ZWGalleryRemoteStatusCode status = [statusNumber intValue];

    [mainProgressIndicator stopAnimation:self];
    
    // TODO: be nicer with errors here
    [mainStatusString setStringValue:[NSString stringWithFormat:@"Unknown error: %i", (int)status]];

    [self updateAlbumPopupMenu];
    [self setLoggedInOut];
    
    selectLastCreatedAlbumWhenDoneFetching = NO;
}

- (void)galleryDidCreateAlbum:(ZWGallery *)sender
{
    [mainStatusString setStringValue:@"Fetching albums..."];
    [currentGallery getAlbums];
    
    selectLastCreatedAlbumWhenDoneFetching = YES;
}

- (void)gallery:(ZWGallery *)sender createAlbumFailedWithCode:(NSNumber *)statusNumber
{
    ZWGalleryRemoteStatusCode status = [statusNumber intValue];

    if (status == ZW_GALLERY_COULD_NOT_CONNECT) {
        [mainProgressIndicator stopAnimation:self];
        [mainStatusString setStringValue:@"Could not connect to the gallery"];
    } 
    else {
        [mainProgressIndicator stopAnimation:self];
        [mainStatusString setStringValue:[NSString stringWithFormat:@"Unknown error: %i", (int)status]];
    }    
}

- (void)galleryDidAddItems:(ZWGalleryRemoteStatusCode)status
{
    
}

#pragma mark -
#pragma mark ZWGalleryAlbumDelegate

- (void)album:(ZWGalleryAlbum *)sender item:(ZWGalleryItem *)item updateBytesSent:(unsigned long)bytes
{
    currentItemProgress = bytes;
    
    double newProgress = (double)currentImageIndex + ((double)currentItemProgress / ((double)currentImageSize + 1000.0));
    
    NSDictionary *progressInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithDouble:newProgress], @"ProgressBarLocation",
        nil];
    [self performSelectorOnMainThread:@selector(updateProgress:) withObject:progressInfo waitUntilDone:NO modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];    
}

#pragma mark -
#pragma mark NSTableViewDatasource

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [galleries count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
    ZWGallery *gallery = [galleries objectAtIndex:rowIndex];
    return [gallery valueForKey:[aTableColumn identifier]];
}

#pragma mark -
#pragma mark GrowlDelegate

- (NSDictionary *)registrationDictionaryForGrowl
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [NSArray arrayWithObjects:
            @"Photo Uploaded to Gallery",
            @"All Photos Uploaded to Gallery",
            @"Export to Gallery Failed",
            nil], GROWL_NOTIFICATIONS_ALL,
        [NSArray arrayWithObjects:
            @"All Photos Uploaded to Gallery",
            @"Export to Gallery Failed",
            nil], GROWL_NOTIFICATIONS_DEFAULT,
        nil];
}

- (NSString *)applicationNameForGrowl
{
    return @"iPhotoToGallery";
}

- (NSData *)applicationIconDataForGrowl
{
    
    NSString *iconPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"iPhotoPluginIcon" ofType:@"tif"];
    return [NSData dataWithContentsOfFile:iconPath];
}

@end
