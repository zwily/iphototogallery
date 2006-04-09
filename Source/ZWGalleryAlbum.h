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

#import <Foundation/Foundation.h>
#import "ZWGallery.h"

@class ZWGalleryItem;

@interface ZWGalleryAlbum : NSObject {
    NSString *title;
    NSString *name;
    NSString *summary;
    
    ZWGallery *gallery;
    ZWGalleryAlbum *parent;
    NSMutableArray *children;    
    NSMutableArray *items;
    
    BOOL canAddItem;
    BOOL canAddSubAlbum;
    
    id delegate;
    
    BOOL cancelled;
}

- (id)initWithTitle:(NSString *)newTitle name:(NSString *)newName gallery:(ZWGallery *)newGallery;
+ (ZWGalleryAlbum *)albumWithTitle:(NSString *)newTitle name:(NSString *)newName gallery:(ZWGallery *)newGallery;

- (id)initWithTitle:(NSString *)newTitle name:(NSString *)newName summary:(NSString *)newSummary nestedIn:(ZWGalleryAlbum *)newParent gallery:(ZWGallery *)newGallery;
- (ZWGalleryAlbum *)albumWithTitle:(NSString *)newTitle name:(NSString *)newName summary:(NSString *)newSummary nestedIn:(ZWGalleryAlbum *)newParent gallery:(ZWGallery *)newGallery;

- (void)setDelegate:(id)newDelegate;
- (id)delegate;

- (void)setParent:(ZWGalleryAlbum *)parent;
- (ZWGalleryAlbum *)parent;

- (void)addChild:(ZWGalleryAlbum *)child;
- (NSArray *)children;

- (void)setCanAddItem:(BOOL)canAddItem;
- (BOOL)canAddItem;
- (BOOL)canAddItemToAlbumOrSub;

- (void)setCanAddSubAlbum:(BOOL)canAddSubAlbum;
- (BOOL)canAddSubAlbum;
- (BOOL)canAddSubToAlbumOrSub;

- (int)depth;

- (NSString *)title;
- (void)setTitle:(NSString *)newTitle;

- (NSString *)name;
- (void)setName:(NSString *)newName;

- (NSString *)summary;
- (void)setSummary:(NSString *)newSummary;

- (ZWGallery *)gallery;
- (void)setGallery:(ZWGallery *)newGallery;

- (void)cancelOperation;
- (ZWGalleryRemoteStatusCode)addItemSynchronously:(ZWGalleryItem *)item;

@end

@interface ZWGalleryAlbum (ZWGalleryAlbumDelegate)

- (void)album:(ZWGalleryAlbum *)sender item:(ZWGalleryItem *)item updateBytesSent:(unsigned long)bytes;

@end
