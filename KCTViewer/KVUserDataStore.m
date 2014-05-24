//
//  KVUserDataStore.m
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-05-13.
//  Copyright (c) 2014 KanColleTool. All rights reserved.
//

#import "KVUserDataStore.h"

@implementation KVUserDataStore

+ (instancetype)sharedDataStore
{
	static KVUserDataStore *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[[self class] alloc] init];
	});
	
	return sharedInstance;
}

- (id)init
{
	if((self = [super init]))
	{
		// The double "KanColleTool" in the paths are because Qt uses <BasePath>/<Company>/<Application>
		_dataPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"KanColleTool/KanColleTool/userdata"];
		_cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"KanColleTool/KanColleTool/userdata"];
	}
	
	return self;
}

- (KVTempFileHandle *)cacheFileHandleForEndpoint:(NSString *)endpoint page:(NSUInteger)page
{
	NSString *relpath = (page == 0 ?
						 [NSString stringWithFormat:@"%@.json", endpoint] :
						 [NSString stringWithFormat:@"%@__%lu.json", endpoint, (unsigned long)page]);
	NSString *path = [_cachePath stringByAppendingPathComponent:relpath];
	
	return [[KVTempFileHandle alloc] initWithDestPath:path];
}

@end
