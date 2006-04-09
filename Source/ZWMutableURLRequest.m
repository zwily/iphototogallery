//
//  ZWMutableURLRequest.m
//  iPhotoToGallery
//
//  Created by Zach Wily on 7/1/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "ZWMutableURLRequest.h"


@implementation ZWMutableURLRequest

- (id)init
{
    if (self = [super init]) {
        encoding = NSUTF8StringEncoding;   // default to UTF-8
    }
    
    return self;
}

- (void)dealloc
{
    [boundaryData release];
    [requestBodyData release];
    
    [super dealloc];
}

- (CFHTTPMessageRef)copyCFHTTPMessageRef
{
    return NULL;
}

- (void)setVariation:(ZWURLRequestPOSTVariation)newVariation
{
    variation = newVariation;
}

- (ZWURLRequestPOSTVariation)variation
{
    return variation;
}

- (void)setEncoding:(NSStringEncoding)newEncoding
{
    encoding = newEncoding;
}

- (NSStringEncoding)encoding
{
    return encoding;
}

- (void)addString:(NSString *)string forName:(NSString *)name
{
    [self addData:[string dataUsingEncoding:encoding] forName:name filename:nil contentType:nil];
}

- (void)addData:(NSData *)data forName:(NSString *)name filename:(NSString *)filename contentType:(NSString *)contentType
{
    if (!requestBodyData) 
        requestBodyData = [[NSMutableData alloc] init];
    
    if (variation == ZSURLEncodedVariation) {
        
    }
    else if (variation == ZSURLMultipartVariation) {
        if (!boundaryData) {
            // ProcessInfo is just an easy way to get a nice long string that's always changing and we're pretty sure
            //   won't show up in any of the post data
            NSString *boundary = [NSString stringWithFormat:@"--%@--", [[NSProcessInfo processInfo] globallyUniqueString]];
            [self setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];

            // The actual boundary we'll be using has to start with "--" and end with \r\n
            boundaryData = [[[[@"--" stringByAppendingString:boundary] stringByAppendingString:@"\r\n"] dataUsingEncoding:encoding] retain];
            
            [requestBodyData appendData:boundaryData];
        }
        
        [requestBodyData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; "] dataUsingEncoding:encoding]];
        
        if (name)
            [requestBodyData appendData:[[NSString stringWithFormat:@"name=\"%@\"; ", name] dataUsingEncoding:encoding]];
        
        if (filename)
            [requestBodyData appendData:[[NSString stringWithFormat:@"filename=\"%@\"; ", filename] dataUsingEncoding:encoding]];
        
        if (contentType)
            [requestBodyData appendData:[[NSString stringWithFormat:@"Content-Type: %@", contentType] dataUsingEncoding:encoding]];
        
        [requestBodyData appendData:[[NSString stringWithFormat:@"\r\n\r\n"] dataUsingEncoding:encoding]];
        
        [requestBodyData appendData:data];
        
        [requestBodyData appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:encoding]];

        [requestBodyData appendData:boundaryData];
    }
    
    [self setHTTPBody:requestBodyData];
}

@end
