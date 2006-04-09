//
//  ZWMutableURLRequest.h
//  iPhotoToGallery
//
//  Created by Zach Wily on 7/1/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//
//  This class extended NSMutableURLRequest by letting you actually set the POST parameters as well.
//  (It build the data content section). I tried doing it with a clever category on NSMutableURLRequest
//  but that ended up being more work than it was worth.
//
//  The cool thing about it is that you can specify URL Encoded or Multipart MIME encoding.
//

#import <Cocoa/Cocoa.h>

typedef enum {
    ZSURLEncodedVariation,
    ZSURLMultipartVariation
} ZWURLRequestPOSTVariation;

@interface ZWMutableURLRequest : NSMutableURLRequest {
    NSData *boundaryData;
    NSMutableData *requestBodyData;
    NSStringEncoding encoding;
    
    ZWURLRequestPOSTVariation variation;
}

- (CFHTTPMessageRef)copyCFHTTPMessageRef;

- (void)setVariation:(ZWURLRequestPOSTVariation)newVariation;
- (ZWURLRequestPOSTVariation)variation;

- (void)setEncoding:(NSStringEncoding)newEncoding;
- (NSStringEncoding)encoding;

- (void)addString:(NSString *)string forName:(NSString *)name;
- (void)addData:(NSData *)data forName:(NSString *)name filename:(NSString *)filename contentType:(NSString *)contentType;

@end
