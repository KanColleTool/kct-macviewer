//
//  KVLogger.m
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-04-07.
//  Copyright (c) 2014 KanColleTool. All rights reserved.
//

#import "KVLogger.h"

#define _int(n) [NSNumber numberWithInt:n]

@interface KVLogger ()

- (void)log:(NSDictionary *)dict to:(NSFileHandle *)handle;

@end

@implementation KVLogger

+ (instancetype)sharedLogger
{
	static dispatch_once_t pred;
	static KVLogger *sharedInstance = nil;
	dispatch_once(&pred, ^{
		sharedInstance = [[KVLogger alloc] init];
	});
	
	return sharedInstance;
}

- (id)init
{
	if((self = [super init]))
	{
		//NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	}
	
	return self;
}

- (void)logDrop:(int)shipID world:(int)world map:(int)map
{
	[self log:@{
				@"ship": _int(shipID),
				@"world": _int(world),
				@"map": _int(map)
				}
		   to:dropLog];
}

- (void)logCraftShip:(int)shipID flagship:(int)flagshipID fuel:(int)fuel ammo:(int)ammo steel:(int)steel baux:(int)baux
{
	[self log:@{
				@"ship": _int(shipID),
				@"flagship": _int(flagshipID),
				@"fuel": _int(fuel),
				@"ammo": _int(ammo),
				@"steel": _int(steel),
				@"baux": _int(baux)
				}
		   to:shipLog];
}

- (void)logCraftItem:(int)itemID flagship:(int)flagshipID fuel:(int)fuel ammo:(int)ammo steel:(int)steel baux:(int)baux
{
	[self log:@{
				@"item": _int(itemID),
				@"flagship": _int(flagshipID),
				@"fuel": _int(fuel),
				@"ammo": _int(ammo),
				@"steel": _int(steel),
				@"baux": _int(baux)
				}
		   to:itemLog];
}

- (void)log:(NSDictionary *)dict to:(NSFileHandle *)handle
{
	
}

@end
