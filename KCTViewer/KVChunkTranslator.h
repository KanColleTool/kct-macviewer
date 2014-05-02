//
//  KVChunkTranslator.h
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-05-02.
//  Copyright (c) 2014 KanColleTool. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <yajl/yajl_parse.h>
#import <yajl/yajl_gen.h>

@interface KVChunkTranslator : NSObject
{
	yajl_callbacks _parser_callbacks;
	yajl_handle _parser;
	yajl_gen _generator;
}

- (NSData *)receivedChunk:(NSData *)chunk;

@end
