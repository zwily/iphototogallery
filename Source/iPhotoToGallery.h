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

#import <Cocoa/Cocoa.h>
#import "iPhotoExporter.h"

@class ZWGallery, ZWGalleryAlbum, ZWGalleryItem;

// This protocol description was class-dump'd out of iPhoto, and we must implement it.
@protocol ExportPluginProtocol
- description;
- name;
- (void)cancelExport;
- (void)unlockProgress;
- (void)lockProgress;
- (void *)progress;
- (void)performExport:fp16;
- (void)startExport:fp16;
- (void)clickExport;
- (char)validateUserCreatedPath:fp16;
- (char)treatSingleSelectionDifferently;
- defaultDirectory;
- defaultFileName;
- getDestinationPath;
- (char)wantsDestinationPrompt;
- requiredFileType;
- (void)viewWillBeDeactivated;
- (void)viewWillBeActivated;
- lastView;
- firstView;
- settingsView;
- initWithExportImageObj:fp16;
@end

// I had to guess at exactly what this struct looked like. I think I got it right, 
// but we're not using the supplied progress sheet anymore so it doesn't matter.
struct progressStruct {
    int location;
    int max;
    NSString* status;
    int unknown;
};

@interface iPhotoToGallery : NSObject <ExportPluginProtocol>
{
    // Everything is all in one nib. Why yes, this was my first ever Cocoa project, thank you very much.
    
    // new album settings view
    IBOutlet id albumSettingsPanel;
    IBOutlet id albumSettingsDescriptionField;
    IBOutlet id albumSettingsNestedInPopup;
    IBOutlet id albumSettingsTitleField;
    IBOutlet id albumSettingsNameField;
    
    // gallery list screen
    IBOutlet id galleryListPanel;
    IBOutlet id galleryListRemoveGalleryButton;
    IBOutlet id galleryListTable;
    
    // new gallery settings view
    IBOutlet id gallerySettingsPanel;
    IBOutlet id gallerySettingsAdvancedBox;
    IBOutlet id gallerySettingsHTTPPasswordField;
    IBOutlet id gallerySettingsHTTPUsernameField;
    IBOutlet id gallerySettingsPasswordField;
    IBOutlet id gallerySettingsURLField;
    IBOutlet id gallerySettingsUseHTTPAuthSwitch;
    IBOutlet id gallerySettingsUsernameField;
    IBOutlet id gallerySettingsUseHTTPSSwitch;
    IBOutlet id gallerySettingsShowAdvancedOptionsString;
    IBOutlet id gallerySettingsShowAdvancedOptionsSwitch;
    
    // main screen
    IBOutlet id mainAddToAlbumPopup;
    IBOutlet id mainCreateNewAlbumButton;
    IBOutlet id mainExportCommentsSwitch;
    IBOutlet id mainGalleryPopup;
    IBOutlet id mainOpenBrowserSwitch;
    IBOutlet id mainScaleImagesHeightField;
    IBOutlet id mainScaleImagesSwitch;
    IBOutlet id mainScaleImagesWidthField;
    IBOutlet id mainStatusString;
    IBOutlet id mainProgressIndicator;
    IBOutlet id mainConnectCancelButton;
    IBOutlet id mainDonateButton;
    
    // password panel
    IBOutlet id passwordPanel;
    IBOutlet id passwordTitleField;
    IBOutlet id passwordDescriptionField;
    IBOutlet id passwordInputField;
    
    // progress panel
    IBOutlet id progressPanel;
    IBOutlet id progressUploadingTextField;
    IBOutlet id progressUploadingDetailField;
    IBOutlet id progressProgressIndicator;
    IBOutlet id progressImageView;
    
    // various views required by ExportMgr
    IBOutlet id firstView;
    IBOutlet id lastView;
    IBOutlet id settingsView;

    // the export manager handed to us by iPhoto
    id exportManager;
    
    NSMutableDictionary *preferences;    
    NSMutableArray *galleries;
    NSString *lastGallerySelected;
    ZWGallery *currentGallery;
    BOOL selectLastCreatedAlbumWhenDoneFetching;
    int indexOfLastGallery;
    NSTimer *showCancelTimer;
    
    unsigned long currentItemProgress;
    unsigned long currentImageSize;
    unsigned long currentImageIndex;
    
    ZWGalleryAlbum *currentAlbum;
    
    int heightOfAdvancedBox;
}

// actions
- (IBAction)clickAlbumSettingsCancel:(id)sender;
- (IBAction)clickAlbumSettingsCreateAlbum:(id)sender;
- (IBAction)clickCreateNewAlbum:(id)sender;
- (IBAction)clickGalleryListDone:(id)sender;
- (IBAction)clickGalleryListRemove:(id)sender;
- (IBAction)clickGalleryListSelectGallery:(id)sender;
- (IBAction)clickGalleryPopup:(id)sender;
- (IBAction)clickGallerySettingsCancel:(id)sender;
- (IBAction)clickGallerySettingsOK:(id)sender;
- (IBAction)clickGallerySettingsShowAdvancedOptions:(id)sender;
- (IBAction)clickGallerySettingsUseHTTPAuth:(id)sender;
- (IBAction)clickScaleImages:(id)sender;
- (IBAction)clickiPhotoToGalleryName:(id)sender;
- (IBAction)clickLogin:(id)sender;
- (IBAction)clickCancelLogin:(id)sender;
- (IBAction)clickDonate:(id)sender;
- (IBAction)clickPasswordOK:(id)sender;
- (IBAction)clickPasswordCancel:(id)sender;
- (IBAction)clickProgressCancel:(id)sender;

- (void)updateGalleryPopupMenu;
- (void)updateGallerySettingsAdvancedOptions;
- (void)updateGallerySettingsHTTPAuthOptionsUpdate;
- (void)savePreferences;
- (void)updateAlbumPopupMenu;
- (void)setLoggedInOut;
- (void)setScaleImages;
- (NSString*)lookupPasswordForCurrentGallery;
- (void)loginToSelectedGallery;

- (void)addItemsThread:(id)target;

- (id)exportManager;

- (NSDictionary *)exportManagerImageDictionaryAtIndex:(int)index;

@end
