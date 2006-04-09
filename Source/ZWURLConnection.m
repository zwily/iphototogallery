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

#import "ZWURLConnection.h"


@implementation ZWURLConnection

#pragma mark Object Life Cycle

+ (ZWURLConnection *)connectionWithRequest:(NSURLRequest *)request
{
    return [[[self alloc] initWithRequest:request] autorelease];
}

- (id)initWithRequest:(NSURLRequest *)request
{
    if (self = [super initWithRequest:request delegate:self]) {
        running = YES;
    }
    
    return self;
}

- (void)dealloc
{
    [data release];
    [response release];
    [error release];
    [super dealloc];
}

#pragma mark NSURLConnection

- (void)cancel
{
    cancelled = YES;
    [super cancel];
    running = NO;
    // TODO: figure out how to receive myself from the freaking run loop here
}

#pragma mark Accessors

- (BOOL)isRunning
{
    return running;
}

- (NSData *)data
{
    return data;
}

- (NSError *)error
{
    return error;
}

- (NSURLResponse *)response
{
    return response;
}

- (BOOL)isCancelled
{
    return cancelled;
}

#pragma mark NSURLConnection Delegate

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)aResponse
{
    response = [aResponse retain];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)someData
{
    if (data == nil) 
        data = [[NSMutableData alloc] init];
    
    [data appendData:someData];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)anError
{
    running = NO;
    error = [anError retain];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    running = NO;
}

@end
