//
//  NSURL+KVUtil.m
//  KCTViewer
//
//  Created by Johannes Ekberg on 2013-12-27.
//  Copyright (c) 2013 the KanColleTool team. All rights reserved.
//

#import "NSURL+KVUtil.h"
#import "NSString+KVUtil.h"

@implementation NSURL (KVUtil)

- (NSDictionary *)queryItems
{
	return [self.query queryItems];
}

@end
