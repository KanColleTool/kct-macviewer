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

- (id)_walk:(id)obj pathForReporting:(NSString *)path key:(NSString *)key;
- (void)reportLine:(NSString *)line forPath:(NSString *)path key:(NSString *)key;

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

- (id)init
{
	if((self = [super init]))
	{
		_manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:@"http://api.comeonandsl.am/"]];
		
		//self.reportBlacklist = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"report_blacklist" ofType:@"json"]] options:0 error:NULL];
	}
	
	return self;
}

- (void)setReportBlacklist:(NSDictionary *)reportBlacklist
{
	if(!_reportBlacklist)
	{
		for(NSDictionary *dict in reportQueue)
			[self reportLine:[dict objectForKey:@"line"] forPath:[dict objectForKey:@"path"] key:[dict objectForKey:@"key"]];
		[reportQueue removeAllObjects];
	}
	_reportBlacklist = reportBlacklist;
}

- (NSString *)translate:(NSString *)line
{
	return [self translate:line pathForReporting:nil key:nil];
}

- (NSString *)translate:(NSString *)line pathForReporting:(NSString *)path key:(NSString *)key
{
	// Don't translate things that are just numbers and punctuation, such as some stats that are sent as
	// strings for no real reason, and timers. Make a set containing only numbers and punctuation, invert it
	// to match everything /but/ it, and check if it contains anything matching this inverted set. If it
	// doesn't, there's nothing to translate.
	NSCharacterSet *set = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789,.:-"] invertedSet];
	if([line rangeOfCharacterFromSet:set].location == NSNotFound)
		return line;
	
	// Use CFStringTransform to unescape the line
	NSMutableString *unescapedLine = [line mutableCopy];
	CFStringTransform((__bridge CFMutableStringRef)unescapedLine, NULL, CFSTR("Any-Hex/Java"), YES);
	
	// Look up a translation
	NSString *crc32 = [NSString stringWithFormat:@"%lu", [unescapedLine crc32]];
	NSString *translation = [self.tldata objectForKey:crc32];
	
	if(translation != nil && (NSNull*)translation != [NSNull null])
	{
		//NSLog(@"TL: %@ -> %@", unescapedLine, translation);
		return translation;
	}
	else
	{
		//NSLog(@"No TL: %@->%@: %@", path, key, unescapedLine);
		// Note the last condition: we only want to report lines that are absent (nil/NULL/0), not ones that are
		// present but untranslated (JSON-null, which is parsed into an [NSNull null]).
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"reportUntranslated"] && [path length] > 0 && translation == nil)
			[self reportLine:unescapedLine forPath:path key:key];
		
		// Set it as [NSNull null] to make sure we don't try to repor the same line twice
		[_tldata setValue:[NSNull null] forKey:crc32];
		
		return line;
	}
}

- (NSData *)translateJSON:(NSData *)json
{
	return [self translateJSON:json pathForReporting:nil];
}

- (NSData *)translateJSON:(NSData *)json pathForReporting:(NSString *)path
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
		NSData *data = [NSJSONSerialization dataWithJSONObject:[self _walk:root pathForReporting:path key:nil] options:0 error:NULL];
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

- (id)_walk:(id)obj pathForReporting:(NSString *)path key:(NSString *)key
{
	if([obj isKindOfClass:[NSDictionary class]])
		for (NSString *dkey in [obj allKeys])
			[obj setObject:[self _walk:[obj objectForKey:dkey] pathForReporting:path key:dkey] forKey:dkey];
	else if([obj isKindOfClass:[NSArray class]])
		for(NSInteger i = 0; i < [obj count]; i++)
			[obj replaceObjectAtIndex:i withObject:[self _walk:[obj objectAtIndex:i] pathForReporting:path key:key]];
	else if([obj isKindOfClass:[NSString class]])
		return [self translate:obj pathForReporting:path key:key];
	
	// Ignore these!
	else if([obj isKindOfClass:[NSNumber class]]) {}
	else if([obj isKindOfClass:[NSNull class]]) {}
	
	else
		NSLog(@"!!!!> Don't know what to do about a %@...", [obj class]);
	
	return obj;
}

- (void)reportLine:(NSString *)line forPath:(NSString *)path key:(NSString *)key
{
	if(_reportBlacklist)
	{
		NSArray *blacklistedKeys = [_reportBlacklist objectForKey:path];
		if(![blacklistedKeys containsObject:key])
		{
			[_manager POST:[NSString stringWithFormat:@"/report/%@", path] parameters:@{@"value": line} success:^(AFHTTPRequestOperation *operation, id responseObject) {
				NSLog(@"Reported untranslated line: %@", line);
			} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
				NSLog(@"Couldn't report untranslated line %@: %@", line, error);
			}];
		}
	}
	else if(!_reportingDisabledDueToErrors)
	{
		[reportQueue addObject:@{@"line": line, @"path": path, @"key": key}];
	}
}

@end
