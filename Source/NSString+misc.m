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

#import "NSString+misc.h"

@implementation NSString(URLEscaping)

static inline BOOL isUrlAlpha(unsigned char _c) {
    return
    (((_c >= 'a') && (_c <= 'z')) ||
     ((_c >= 'A') && (_c <= 'Z')))
    ? YES : NO;
}
static inline BOOL isUrlDigit(unsigned char _c) {
    return ((_c >= '0') && (_c <= '9')) ? YES : NO;
}
static inline BOOL isUrlSafeChar(unsigned char _c) {
    switch (_c) {
        case '$': case '-': case '_': case '@':
        case '.': case '&': case '+':
            return YES;

        default:
            return NO;
    }
}
static inline BOOL isUrlExtraChar(unsigned char _c) {
    switch (_c) {
        case '!': case '*': case '"': case '\'':
        case '|': case ',':
            return YES;
    }
    return NO;
}
static inline BOOL isUrlEscapeChar(unsigned char _c) {
    return (_c == '%') ? YES : NO;
}
static inline BOOL isUrlReservedChar(unsigned char _c) {
    switch (_c) {
        case '=': case ';': case '/':
        case '#': case '?': case ':':
        case ' ':
            return YES;
    }
    return NO;
}

static inline BOOL isUrlXalpha(unsigned char _c) {
    if (isUrlAlpha(_c))      return YES;
    if (isUrlDigit(_c))      return YES;
    if (isUrlSafeChar(_c))   return YES;
    if (isUrlExtraChar(_c))  return YES;
    if (isUrlEscapeChar(_c)) return YES;
    return NO;
}

static inline BOOL isUrlHexChar(unsigned char _c) {
    if (isUrlDigit(_c))
        return YES;
    if ((_c >= 'a') && (_c <= 'f'))
        return YES;
    if ((_c >= 'A') && (_c <= 'F'))
        return YES;
    return NO;
}

static inline BOOL isUrlAlphaNum(unsigned char _c) {
    return (isUrlAlpha(_c) || isUrlDigit(_c)) ? YES : NO;
}

static inline BOOL isToBeEscaped(unsigned char _c) {
    return (isUrlAlphaNum(_c) || (_c == '_')) ? NO : YES;
}

static void
NGEscapeUrlBuffer(const unsigned char *_source, unsigned char *_dest)
{
    register const unsigned char *src = (void*)_source;
    while (*src) {
        //if (*src == ' ') { // a ' ' becomes a '+'
        //  *_dest = '+'; _dest++;
        //}
        if (!isToBeEscaped(*src)) {
            *_dest = *src;
            _dest++;
        }
        else { // any other char is escaped ..
            *_dest = '%'; _dest++;
            sprintf(_dest, "%02X", (unsigned)*src);
            _dest += 2;
        }
        src++;
    }
*_dest = '\0';
}

static inline int _valueOfHexChar(register unichar _c) {
    switch (_c) {
        case '0': case '1': case '2': case '3': case '4':
        case '5': case '6': case '7': case '8': case '9':
            return (_c - 48); // 0-9 (ascii-char)'0' - 48 => (int)0

        case 'A': case 'B': case 'C':
        case 'D': case 'E': case 'F':
            return (_c - 55); // A-F, A=10..F=15, 'A'=65..'F'=70

        case 'a': case 'b': case 'c':
        case 'd': case 'e': case 'f':
            return (_c - 87); // a-f, a=10..F=15, 'a'=97..'f'=102

        default:
            return -1;
    }
}
static inline BOOL _isHexDigit(register unichar _c) {
    switch (_c) {
        case '0': case '1': case '2': case '3': case '4':
        case '5': case '6': case '7': case '8': case '9':
        case 'A': case 'B': case 'C':
        case 'D': case 'E': case 'F':
        case 'a': case 'b': case 'c':
        case 'd': case 'e': case 'f':
            return YES;

        default:
            return NO;
    }
}

static void
NGUnescapeUrlBuffer(const unsigned char *_source, unsigned char *_dest)
{
    BOOL done = NO;

    while (!done && (*_source != '\0')) {
        char c = *_source;

        if (c == '+') // '+' stands for a space
          *_dest = ' ';
        else if (c == '%') {
            _source++; c = *_source;

            if (c == '\0') {
                *_dest = '%';
                done = YES;
            }
            else if (_isHexDigit(c)) { // hex-escaped char, like '%F3'
                int decChar = _valueOfHexChar(c);
                _source++;
                c = *_source;
                decChar = decChar * 16 + _valueOfHexChar(c);
                *_dest = (unsigned char)decChar;
            }
            else // escaped char, like '%%' -> '%'
                *_dest = c;
        }
        else // char passed through
            *_dest = c;

        _dest++;
        _source++;
    }
    *_dest = '\0';
}

- (BOOL)containsURLEscapeCharacters {
    register unsigned i, len;
    register unichar (*charAtIdx)(id,SEL,unsigned);
    register unichar charAtIndex;

    if ((len = [self length]) == 0) return NO;

    charAtIdx = (void*)[self methodForSelector:@selector(characterAtIndex:)];
    for (i = 0; i < len; i++) {
        charAtIndex = charAtIdx(self, @selector(characterAtIndex:), i);
        if ((charAtIndex == '%') || (charAtIndex == '+'))
            return YES;
    }
    return NO;
}
- (BOOL)containsURLInvalidCharacters {
    register unsigned i, len;
    register unichar (*charAtIdx)(id,SEL,unsigned);

    if ((len = [self length]) == 0) return NO;

    charAtIdx = (void*)[self methodForSelector:@selector(characterAtIndex:)];
    for (i = 0; i < len; i++) {
        if (isToBeEscaped(charAtIdx(self, @selector(characterAtIndex:), i)))
            return YES;
    }
    return NO;
}

- (NSString *)stringByUnescapingURL {
    unsigned len;
    char     *cstr;
    char     *buffer = NULL;
    NSString *s;

    if (![self containsURLEscapeCharacters])
        return [[self copy] autorelease];

    if ((len = [self cStringLength]) == 0) return @"";

    cstr = malloc(len + 10);
    [self getCString:cstr];
    cstr[len] = '\0';

    buffer = malloc(len + 2);
    NGUnescapeUrlBuffer(cstr, buffer);
    s = [[NSString alloc]
                 initWithCStringNoCopy:buffer
                                length:strlen(buffer)
                          freeWhenDone:YES];
    if (cstr) free(cstr);
    return [s autorelease];
}

NSString *URLEscapeString(NSString *str) 
{
    NSString *escapedString = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                  (CFStringRef)str,
                                                                                  NULL,
                                                                                  NULL,
                                                                                  kCFStringEncodingISOLatin1);
    return [escapedString autorelease];    
}

- (NSString *)stringByEscapingURL {
    return URLEscapeString(self);
    
    unsigned len;
    char     *cstr;
    NSString *s;
    char     *buffer = NULL;

    if ((len = [self cStringLength]) == 0) return @"";

    if (![self containsURLInvalidCharacters]) // needs to be escaped ?
        return [[self copy] autorelease];

    cstr = malloc(len + 1);
    [self getCString:cstr];
    cstr[len] = '\0';

    buffer = malloc([self cStringLength] * 3 + 2);
    NGEscapeUrlBuffer(cstr, buffer);

    s = [[NSString alloc]
                 initWithCStringNoCopy:buffer
                                length:strlen(buffer)
                          freeWhenDone:YES];
    free(cstr);
    return [s autorelease];
}

@end
