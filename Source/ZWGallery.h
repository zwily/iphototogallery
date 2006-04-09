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

@class ZWGalleryAlbum;
@class ZWURLConnection;

typedef enum
{
    GR_STAT_SUCCESS = 0,                       // The command the client sent in the request completed successfully. The data (if any) in the response should be considered valid.    
    GR_STAT_PROTO_MAJ_VER_INVAL = 101,         // The protocol major version the client is using is not supported.
    GR_STAT_PROTO_MIN_VER_INVAL = 102,         // The protocol minor version the client is using is not supported.    
    GR_STAT_PROTO_VER_FMT_INVAL = 103,         // The format of the protocol version string the client sent in the request is invalid.    
    GR_STAT_PROTO_VER_MISSING = 104,           // The request did not contain the required protocol_version key.
    GR_STAT_PASSWD_WRONG = 201,                // The password and/or username the client send in the request is invalid.
    GR_STAT_LOGIN_MISSING = 202,               // The client used the login command in the request but failed to include either the username or password (or both) in the request.
    GR_STAT_UNKNOWN_CMD = 301,                 // The value of the cmd key is not valid.    
    GR_STAT_NO_ADD_PERMISSION = 401,           // The user does not have permission to add an item to the gallery.
    GR_STAT_NO_FILENAME = 402,                 // No filename was specified.
    GR_STAT_UPLOAD_PHOTO_FAIL = 403,           // The file was received, but could not be processed or added to the album.
    GR_STAT_NO_WRITE_PERMISSION = 404,         // No write permission to destination album.
    GR_STAT_NO_CREATE_ALBUM_PERMISSION = 501,  // A new album could not be created because the user does not have permission to do so.
    GR_STAT_CREATE_ALBUM_FAILED = 502,         // A new album could not be created, for a different reason (name conflict).
    ZW_GALLERY_COULD_NOT_CONNECT = 1000,       // Could not connect to the gallery
    ZW_GALLERY_PROTOCOL_ERROR = 1001,          // Something went wrong with the protocol (no status sent, couldn't decode, etc)
    ZW_GALLERY_UNKNOWN_ERROR = 1002,
    ZW_GALLERY_OPERATION_DID_CANCEL = 1003     // The user cancelled whatever operation was happening
} ZWGalleryRemoteStatusCode;

typedef enum
{
    GalleryTypeG1 = 0,
    GalleryTypeG2,
    GalleryTypeG2XMLRPC
} ZWGalleryType;

@interface ZWGallery : NSObject {
    NSURL* url;
    NSURL* fullURL;
    NSString* username;
    NSString* password;
    ZWGalleryType type;
    
    BOOL loggedIn;
    int majorVersion;
    int minorVersion;
    NSArray* albums;
    NSString *lastCreatedAlbumName;
    
    NSStringEncoding sniffedEncoding;
    
    id delegate;    
    ZWURLConnection *currentConnection;
}

- (id)init;
- (id)initWithURL:(NSURL *)url username:(NSString *)username;
- (id)initWithDictionary:(NSDictionary *)description;
+ (ZWGallery *)galleryWithURL:(NSURL *)url username:(NSString *)username;
+ (ZWGallery *)galleryWithDictionary:(NSDictionary *)description;

- (void)cancelOperation;
- (void)login;
- (void)logout;
- (void)createAlbumWithName:(NSString *)name title:(NSString *)title summary:(NSString *)summary parent:(ZWGallery *)parent;
- (void)getAlbums;

// accessor methods
- (NSURL *)url;
- (NSURL *)fullURL;
- (NSString *)identifier;
- (NSString *)urlString;
- (NSString *)username;
- (int)majorVersion;
- (int)minorVersion;
- (BOOL)loggedIn;
- (NSArray *)albums;
- (NSDictionary *)infoDictionary;
- (ZWGalleryType)type;
- (BOOL)isGalleryV2;
- (void)setDelegate:(id)delegate;
- (id)delegate;
- (void)setPassword:(NSString *)password;
- (NSString *)lastCreatedAlbumName;
- (NSStringEncoding)sniffedEncoding;

// This helper method can be used by children too
- (NSDictionary *)parseResponseData:(NSData*)responseData;
- (NSString *)formNameWithName:(NSString *)paramName;

@end

@interface ZWGallery (ZWGalleryDelegateMethods)

- (void)galleryDidLogin:(ZWGallery *)sender;
- (void)gallery:(ZWGallery *)sender loginFailedWithCode:(ZWGalleryRemoteStatusCode)status;

- (void)galleryDidGetAlbums:(ZWGallery *)sender;
- (void)gallery:(ZWGallery *)sender getAlbumsFailedWithCode:(ZWGalleryRemoteStatusCode)status;

- (void)galleryDidCreateAlbum:(ZWGallery *)sender;
- (void)gallery:(ZWGallery *)sender createAlbumFailedWithCode:(ZWGalleryRemoteStatusCode)status;

@end
