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

#import "ZWTransitionImageView.h"
#import <Quartz/Quartz.h>

static NSBitmapImageRep *BitmapImageRepFromNSImage(NSImage *nsImage);

@interface MyViewAnimation : NSAnimation
@end

@implementation ZWTransitionImageView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)dealloc
{
    [image release];
    [oldImage release];
    [super dealloc];
}

- (void)awakeFromNib {
    // Preload shading bitmap to use in transitions (borrowed from the "Fun House" Core Image example).
    /*
    NSData *shadingBitmapData = [NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"restrictedshine" ofType:@"tiff"]];
    NSBitmapImageRep *shadingBitmap = [[[NSBitmapImageRep alloc] initWithData:shadingBitmapData] autorelease];
    inputShadingImage = [[CIImage alloc] initWithBitmapImageRep:shadingBitmap];
    */
}

#pragma mark Accessors

- (void)setImage:(NSImage *)newImage
{
    BOOL imageWasBlank = imageIsBlank;
    imageIsBlank = (newImage == nil);
    
    // save the previous image
    [oldImage autorelease];
    oldImage = image;
    
    // create a new matted image with the image we were given
    NSRect borderRect = NSInsetRect([self bounds], 4, 4);
    NSSize newImageSize = [newImage size];
    mattedImageRect = NSInsetRect(borderRect, 5, 5);
    image = [[NSImage alloc] initWithSize:[self bounds].size];
    
    float aspect = newImageSize.width / newImageSize.height;
    
    NSRect newImageRect = NSZeroRect;
    if (aspect > 1.0) {
        newImageRect.size.width = mattedImageRect.size.width;
        newImageRect.size.height = newImageRect.size.width / aspect;
        newImageRect.origin.x = mattedImageRect.origin.x;
        newImageRect.origin.y = (mattedImageRect.size.height - newImageRect.size.height) / 2 + mattedImageRect.origin.y;
    }
    else {
        newImageRect.size.height = mattedImageRect.size.height;
        newImageRect.size.width = newImageRect.size.height * aspect;
        newImageRect.origin.y = mattedImageRect.origin.y;
        newImageRect.origin.x = (mattedImageRect.size.width - newImageRect.size.width) / 2 + mattedImageRect.origin.x;
    }
    
    [image lockFocus]; {

        NSBezierPath* path = [NSBezierPath bezierPath];
        float radius = MIN(5, 0.5f * MIN(NSWidth(borderRect), NSHeight(borderRect)));
        NSRect rect = NSInsetRect(borderRect, radius, radius);
        [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMinY(rect)) radius:radius startAngle:180.0 endAngle:270.0];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMinY(rect)) radius:radius startAngle:270.0 endAngle:360.0];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMaxY(rect)) radius:radius startAngle:  0.0 endAngle: 90.0];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMaxY(rect)) radius:radius startAngle: 90.0 endAngle:180.0];
        [path closePath];
        [path setLineWidth:2.0];
        
        // background
        [[NSColor whiteColor] setFill];
        [path fill];
        
        // black border
        [[NSColor grayColor] set];
        [path stroke];
        
        [newImage drawInRect:newImageRect 
                    fromRect:NSMakeRect(0, 0, newImageSize.width, newImageSize.height) 
                   operation:NSCompositeSourceOver 
                    fraction:1.0];

        [path stroke];

    } [image unlockFocus];

    Class CIImageClass = NSClassFromString(@"CIImage");
    if (oldImage && image && !imageIsBlank && !imageWasBlank && actualOldImage != newImage && CIImageClass != nil) {
        NSBitmapImageRep *initialBitmap = BitmapImageRepFromNSImage(oldImage);
        NSBitmapImageRep *finalBitmap = BitmapImageRepFromNSImage(image);
        
        id initialCIImage = [[CIImageClass alloc] initWithBitmapImageRep:initialBitmap];
        id finalCIImage = [[CIImageClass alloc] initWithBitmapImageRep:finalBitmap];

        NSRect rect = [self bounds];
        
        /* Page curl transition - busted at small sizes like we need
        transitionFilter = [[CIFilter filterWithName:@"CIPageCurlTransition"] retain];
        [transitionFilter setDefaults];
        [transitionFilter setValue:[NSNumber numberWithFloat:-M_PI_4] forKey:@"inputAngle"];
        [transitionFilter setValue:initialCIImage forKey:@"inputBacksideImage"];
        [transitionFilter setValue:inputShadingImage forKey:@"inputShadingImage"];
        [transitionFilter setValue:[CIVector vectorWithX:rect.origin.x Y:rect.origin.y Z:rect.size.width W:rect.size.height] forKey:@"inputExtent"];
        */
        
        Class CIFilterClass = NSClassFromString(@"CIFilter");
        transitionFilter = [[CIFilterClass filterWithName:@"CICopyMachineTransition"] retain];
        [transitionFilter setDefaults];
        Class CIVectorClass = NSClassFromString(@"CIVector");
        [transitionFilter setValue:[CIVectorClass vectorWithX:rect.origin.x Y:rect.origin.y Z:rect.size.width W:rect.size.height] forKey:@"inputExtent"];
        
        [transitionFilter setValue:initialCIImage forKey:@"inputImage"];
        [transitionFilter setValue:finalCIImage forKey:@"inputTargetImage"];
        
        [initialCIImage release];
        [finalCIImage release];

        animation = [[MyViewAnimation alloc] initWithDuration:0.7 animationCurve:NSAnimationEaseInOut];
        [animation setDelegate:self];
        [animation setAnimationBlockingMode:NSAnimationNonblocking];
        
        [animation startAnimation];
    }
    
    [self setNeedsDisplay:YES];
    
    [actualOldImage autorelease];
    actualOldImage = [newImage retain];
}

- (NSImage *)image
{
    return image;
}

- (void)animationDidEnd:(NSAnimation*)theAnimation {
    [animation autorelease];
    animation = nil;
    [transitionFilter release];
    transitionFilter = nil;
}

#pragma mark NSView

- (void)drawRect:(NSRect)rect 
{
    if (animation != nil) {
        [transitionFilter setValue:[NSNumber numberWithFloat:[animation currentValue]] forKey:@"inputTime"];
        id outputCIImage = [transitionFilter valueForKey:@"outputImage"];
        
        // Composite the outputImage into the view (which triggers on-demand rendering of the result).
        [outputCIImage drawInRect:[self bounds] fromRect:NSMakeRect(0, 0, [self bounds].size.width, [self bounds].size.height) operation:NSCompositeSourceOver fraction:1.0];
    }
    else {
        [image drawAtPoint:NSMakePoint(0, 0) 
                  fromRect:NSMakeRect(0, 0, [self bounds].size.width, [self bounds].size.height) 
                 operation:NSCompositeSourceOver 
                  fraction:1.0];
    }
}

@end

@implementation MyViewAnimation

// Override NSAnimation's -setCurrentProgress: method, and use it as our point to hook in and advance our Core Image transition effect to the next time slice.
- (void)setCurrentProgress:(NSAnimationProgress)progress {
    // First, invoke super's implementation, so that the NSAnimation will remember the proposed progress value and hand it back to us when we ask for it in AnimatingTabView's -drawRect: method.
    [super setCurrentProgress:progress];
    
    // Now ask the AnimatingTabView (which set itself as our delegate) to display.  Sending a -display message differs from sending -setNeedsDisplay: or -setNeedsDisplayInRect: in that it demands an immediate, syncrhonous redraw of the view.  Most of the time, it's preferrable to send a -setNeedsDisplay... message, which gives AppKit the opportunity to coalesce potentially numerous display requests and update the window efficiently when it's convenient.  But for a syncrhonously executing animation, it's appropriate to use -display.
    [[self delegate] display];
}

@end

static NSBitmapImageRep *BitmapImageRepFromNSImage(NSImage *nsImage) {
    // See if the NSImage has an NSBitmapImageRep.  If so, return the first NSBitmapImageRep encountered.  An NSImage that is initialized by loading the contents of a bitmap image file (such as JPEG, TIFF, or PNG) and, not subsequently rescaled, will usually have a single NSBitmapImageRep.
    NSEnumerator *enumerator = [[nsImage representations] objectEnumerator];
    NSImageRep *representation;
    while (representation = [enumerator nextObject]) {
        if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
            return (NSBitmapImageRep *)representation;
        }
    }
    
    // If we didn't find an NSBitmapImageRep (perhaps because we received a PDF image), we can create one using one of two approaches: (1) lock focus on the NSImage, and create the bitmap using -[NSBitmapImageRep initWithFocusedViewRect:], or (2) (Tiger and later) create an NSBitmapImageRep, and an NSGraphicsContext that draws into it using +[NSGraphicsContext graphicsContextWithBitmapImageRep:], and composite the NSImage into the bitmap graphics context.  We'll use approach (1) here, since it is simple and supported on all versions of Mac OS X.
    NSSize size = [nsImage size];
    [nsImage lockFocus];
    NSBitmapImageRep *bitmapImageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, size.width, size.height)];
    [nsImage unlockFocus];
    
    return [bitmapImageRep autorelease];
}
