//
//  KVLogger.h
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-04-07.
//  Copyright (c) 2014 KanColleTool. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KVLogger : NSObject
{
	NSFileHandle *dropLog, *shipLog, *itemLog;
}

+ (instancetype)sharedLogger;

- (void)logDrop:(int)shipID world:(int)world map:(int)map;
- (void)logCraftShip:(int)shipID flagship:(int)flagshipID fuel:(int)fuel ammo:(int)ammo steel:(int)steel baux:(int)baux;
- (void)logCraftItem:(int)itemID flagship:(int)flagshipID fuel:(int)fuel ammo:(int)ammo steel:(int)steel baux:(int)baux;

@end
