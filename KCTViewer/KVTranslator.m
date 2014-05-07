//
//  KVTranslator.m
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-01-21.
//  Copyright (c) 2014 the KanColleTool team. All rights reserved.
//

#import "KVTranslator.h"
#import "NSString+KVHashes.h"

@interface KVTranslator ()

- (id)_walk:(id)obj;

@end

@implementation KVTranslator

+ (instancetype)sharedTranslator
{
	static dispatch_once_t pred;
    static KVTranslator *sharedInstance = nil;
    dispatch_once(&pred, ^{
        sharedInstance = [[KVTranslator alloc] init];
    });
	
    return sharedInstance;
}

- (NSString *)translate:(NSString *)line
{
	// Don't translate things that are just numbers and punctuation, such as some stats that are sent as
	// strings for no real reason and timers. Make a set containing only numbers and punctuation, invert it
	// to match everything /but/ it, and check if it contains anything matching this inverted set. If it
	// doesn't, there's nothing to translate.
	NSCharacterSet *set = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789,.:-"] invertedSet];
	if([line rangeOfCharacterFromSet:set].location == NSNotFound)
		return line;
	
	// Use CFStringTransform to unescape the line
	NSMutableString *unescapedLine = [line mutableCopy];
	CFStringTransform((__bridge CFMutableStringRef)unescapedLine, NULL, CFSTR("Any-Hex/Java"), YES);
	
	// Look up a translation
	NSString *translation = [self.tldata objectForKey:[NSString stringWithFormat:@"%lu", [unescapedLine crc32]]];
	
	if(translation != nil && (NSNull*)translation != [NSNull null])
	{
		//NSLog(@"TL: %@ -> %@", unescapedLine, translation);
		return translation;
	}
	else
	{
		//NSLog(@"No TL: %@", unescapedLine);
		return line;
	}
}

- (NSData *)translateJSON:(NSData *)json
{
	// Skip the svdata= prefix if it exists
	NSData *prefixData = [@"svdata=" dataUsingEncoding:NSUTF8StringEncoding];
	BOOL hasPrefix = [[json subdataWithRange:NSMakeRange(0, [prefixData length])] isEqual:prefixData];
	
	// Deserialize the root object
	NSError *error = nil;
	id root = [NSJSONSerialization JSONObjectWithData:(!hasPrefix ? json : [json subdataWithRange:NSMakeRange(7, [json length]-7)])
											  options:NSJSONReadingMutableContainers|NSJSONReadingAllowFragments error:&error];
	
	if(!error)
	{
		NSData *data = [NSJSONSerialization dataWithJSONObject:[self _walk:root] options:0 error:NULL];
		if(!hasPrefix)
			return data;
		else
		{
			NSMutableData *outdata = [[NSMutableData alloc] initWithCapacity:[prefixData length] + [data length]];
			[outdata appendData:prefixData];
			[outdata appendData:data];
			return outdata;
		}
	}
	else
	{
		NSLog(@"JSON Error: %@", error);
		return json;
	}
}

- (id)_walk:(id)obj
{
	if([obj isKindOfClass:[NSDictionary class]])
		for (id<NSCopying> key in [obj allKeys])
			[obj setObject:[self _walk:[obj objectForKey:key]] forKey:key];
	else if([obj isKindOfClass:[NSArray class]])
		for(NSInteger i = 0; i < [obj count]; i++)
			[obj replaceObjectAtIndex:i withObject:[self _walk:[obj objectAtIndex:i]]];
	else if([obj isKindOfClass:[NSString class]])
		return [self translate:obj];
	
	// Ignore these!
	else if([obj isKindOfClass:[NSNumber class]]) {}
	else if([obj isKindOfClass:[NSNull class]]) {}
	
	else
		NSLog(@"!!!!> Don't know what to do about a %@...", [obj class]);
	
	return obj;
}

@end
