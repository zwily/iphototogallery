//
//  iPhotoExporter.h
//
//  These are the classes and protocols that will be interesting to us when we're running inside iPhoto.
//  If I remember correctly these were class-dump'd from iPhoto 2, and have been stable since then (with
//  one minor exception.) Thanks Apple!
//

#import <Foundation/Foundation.h>

@protocol ExportImageProtocol
- (struct _NSSize)lastThumbnailSize:(void *)fp12;
- (struct _NSSize)lastImageSize:(void *)fp16;
- (char)thumbnailer:(void *)fp16 createThumbnail:fp20 dest:fp24;
- thumbnailerOutputExtension:(void *)fp12;
- (void)setThumbnailer:(void *)fp12 outputExtension:fp16;
- (unsigned int)thumbnailerOutputFormat:(void *)fp12;
- (void)setThumbnailer:(void *)fp12 outputFormat:(unsigned int)fp16;
- (float)thumbnailerRotation:(void *)fp12;
- (void)setThumbnailer:(void *)fp12 rotation:(float)fp40;
- (int)thumbnailerQuality:(void *)fp12;
- (void)setThumbnailer:(void *)fp12 quality:(int)fp16;
- (struct _NSSize)thumbnailerMaxBounds:(void *)fp12;
- (void)setThumbnailer:(void *)fp16 maxBytes:(unsigned int)fp20 maxWidth:(unsigned int)fp24 maxHeight:(unsigned int)fp28;
- (void)releaseThumbnailer:(void *)fp12;
- (void *)autoreleaseThumbnailer:(void *)fp12;
- (void *)retainThumbnailer:(void *)fp12;
- (void *)createThumbnailer;
- (struct OpaqueGrafPtr *)uncompressImage:fp12 size:(struct _NSSize)fp16 pixelFormat:(unsigned int)fp24 rotation:(float)fp40 colorProfile:(STR **)fp32;
- (unsigned int)getImageFormatForExtension:fp12;
- getExtensionForImageFormat:(unsigned int)fp12;
- validFilename:fp12;
- (char)ensurePermissions:(unsigned long)fp12 forPath:fp16;
- stringByResolvingAliasesInPath:fp12;
- pathContentOfAliasAtPath:fp12;
- (char)isAliasFileAtPath:fp12;
- (unsigned long long)sizeAtPath:fp12 count:(unsigned long *)fp16 physical:(char)fp20;
- (unsigned long)countFilesFromArray:fp12 descend:(char)fp16;
- (unsigned long)countFiles:fp12 descend:(char)fp16;
- pathForFSRef:(struct FSRef *)fp12;
- (char)getFSRef:(struct FSRef *)fp12 forPath:fp16 isDirectory:(char)fp20;
- pathForFSSpec:fp12;
- (char)makeFSSpec:fp12 spec:(struct FSSpec *)fp16;
- makeUniqueFileNameWithTime:fp12;
- makeUniqueFilePath:fp12 extension:fp16;
- makeUniquePath:fp12;
- uniqueSubPath:fp12 child:fp16;
- (char)createDir:fp12;
- (char)doesDirectoryExist:fp12;
- (char)doesFileExist:fp12;
- temporaryDirectory;
- directoryPath;
- (void)cancelExportBeforeBeginning;
- (void)cancelExport;
- (void)startExport;
- (void)clickExport;
- (void)disableControls;
- (void)enableControls;
- window;
- (unsigned int)albumPositionOfImageAtIndex:(unsigned int)fp12;
- (unsigned int)albumCount;
- albumMusicPath;
- albumName;
- selectedAlbums;
- (float)imageAspectRatioAtIndex:(unsigned int)fp12;
- imageDictionaryAtIndex:(unsigned int)fp12;
- thumbnailPathAtIndex:(unsigned int)fp12;
- imagePathAtIndex:(unsigned int)fp12;
- imageCaptionAtIndex:(unsigned int)fp12;
- imageTitleAtIndex:(unsigned int)fp12; // added in iPhoto 7
- imageCommentsAtIndex:(unsigned int)fp12; // added in iPhoto 5
- (unsigned int)imageFormatAtIndex:(unsigned int)fp12;
- (struct _NSSize)imageSizeAtIndex:(unsigned int)fp12;
- (char)imageIsPortraitAtIndex:(unsigned int)fp16;
- (unsigned int)imageCount;
@end

@interface ExportController:NSObject
{
    id mWindow;
    id mExportView;
    id mExportButton;
    id mImageCount;
    id *mExportMgr;
    id *mCurrentPluginRec;
    id *mProgressController;
    char mCancelExport;
    NSTimer *mTimer;
    NSString *mDirectoryPath;
}

- (void)awakeFromNib;
- (void)dealloc;
- currentPlugin;
- currentPluginRec;
- (void)setCurrentPluginRec:fp12;
- directoryPath;
- (void)setDirectoryPath:fp12;
- (void)show;
- (void)_openPanelDidEnd:fp12 returnCode:(int)fp16 contextInfo:(void *)fp20;
- panel:fp12 userEnteredFilename:fp16 confirmed:(char)fp20;
- (char)panel:fp12 shouldShowFilename:fp16;
- (char)panel:fp12 isValidFilename:fp16;
- (char)filesWillFitOnDisk;
- (void)export:fp12;
- (void)_exportThread:fp12;
- (void)_exportProgress:fp12;
- (void)startExport:fp12;
- (void)finishExport;
- (void)cancelExport;
- (void)cancel:fp12;
- (void)enableControls;
- window;
- (void)disableControls;
- (void)tabView:fp12 willSelectTabViewItem:fp16;
- (void)tabView:fp12 didSelectTabViewItem:fp16;
- (void)selectExporter:fp12;
- exportView;
- (char)_hasPlugins;
- (void)_resizeExporterToFitView:fp12;
- (void)_updateImageCount;

@end

@interface ExportMgr:NSObject <ExportImageProtocol>
{
    id *mDocument;
    NSMutableArray *mExporters;
    id *mExportAlbum;
    NSArray *mSelection;
    NSArray *mSelectedAlbums;
    ExportController *mExportController;
} 

+ exportMgr;
+ exportMgrNoAlloc;
- init;
- (void)dealloc;
- (void)releasePlugins;
- (void)setExportController:fp12;
- (ExportController*)exportController;
- (void)setDocument:fp12;
- document;
- (void)updateDocumentSelection;
- (unsigned int)count;
- recAtIndex:(unsigned int)fp12;
- (void)scanForExporters;
- (unsigned int)imageCount;
- (char)imageIsPortraitAtIndex:(unsigned int)fp12;
- imagePathAtIndex:(unsigned int)fp12;
- (struct _NSSize)imageSizeAtIndex:(unsigned int)fp16;
- (unsigned int)imageFormatAtIndex:(unsigned int)fp12;
- imageCaptionAtIndex:(unsigned int)fp12;
- thumbnailPathAtIndex:(unsigned int)fp12;
- imageDictionaryAtIndex:(unsigned int)fp12;
- (float)imageAspectRatioAtIndex:(unsigned int)fp12;
- selectedAlbums;
- albumComments;
- albumName;
- albumMusicPath;
- (unsigned int)albumCount;
- (unsigned int)albumPositionOfImageAtIndex:(unsigned int)fp12;
- imageRecAtIndex:(unsigned int)fp12;
- currentAlbum;
- (void)enableControls;
- (void)disableControls;
- window;
- (void)clickExport;
- (void)startExport;
- (void)cancelExport;
- (void)cancelExportBeforeBeginning;
- directoryPath;
- temporaryDirectory;
- (char)doesFileExist:fp12;
- (char)doesDirectoryExist:fp12;
- (char)createDir:fp12;
- uniqueSubPath:fp12 child:fp16;
- makeUniquePath:fp12;
- makeUniqueFilePath:fp12 extension:fp16;
- makeUniqueFileNameWithTime:fp12;
- (char)makeFSSpec:fp12 spec:(struct FSSpec *)fp16;
- pathForFSSpec:fp12;
- (char)getFSRef:(struct FSRef *)fp12 forPath:fp16 isDirectory:(char)fp20;
- pathForFSRef:(struct FSRef *)fp12;
- (unsigned long)countFiles:fp12 descend:(char)fp16;
- (unsigned long)countFilesFromArray:fp12 descend:(char)fp16;
- (unsigned long long)sizeAtPath:fp12 count:(unsigned long *)fp16 physical:(char)fp20;
- (char)isAliasFileAtPath:fp12;
- pathContentOfAliasAtPath:fp12;
- stringByResolvingAliasesInPath:fp12;
- (char)ensurePermissions:(unsigned long)fp12 forPath:fp16;
- validFilename:fp12;
- getExtensionForImageFormat:(unsigned int)fp12;
- (unsigned int)getImageFormatForExtension:fp12;
- (struct OpaqueGrafPtr *)uncompressImage:fp12 size:(struct _NSSize)fp16 pixelFormat:(unsigned int)fp24 rotation:(float)fp40 colorProfile:(STR **)fp32;
- (void *)createThumbnailer;
- (void *)retainThumbnailer:(void *)fp12;
- (void *)autoreleaseThumbnailer:(void *)fp12;
- (void)releaseThumbnailer:(void *)fp12;
- (void)setThumbnailer:(void *)fp12 maxBytes:(unsigned int)fp16 maxWidth:(unsigned int)fp20 maxHeight:(unsigned int)fp24;
- (struct _NSSize)thumbnailerMaxBounds:(void *)fp16;
- (void)setThumbnailer:(void *)fp12 quality:(int)fp16;
- (int)thumbnailerQuality:(void *)fp12;
- (void)setThumbnailer:(void *)fp12 rotation:(float)fp40;
- (float)thumbnailerRotation:(void *)fp12;
- (void)setThumbnailer:(void *)fp12 outputFormat:(unsigned int)fp16;
- (unsigned int)thumbnailerOutputFormat:(void *)fp12;
- (void)setThumbnailer:(void *)fp12 outputExtension:fp16;
- thumbnailerOutputExtension:(void *)fp12;
- (char)thumbnailer:(void *)fp12 createThumbnail:fp16 dest:fp20;
- (struct _NSSize)lastImageSize:(void *)fp16;
- (struct _NSSize)lastThumbnailSize:(void *)fp16;

@end


