//
//  KVChunkTranslator.h
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-05-02.
//  Copyright (c) 2014 KanColleTool. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <yajl_parse.h>
#import <yajl_gen.h>

typedef struct {
	const unsigned char *key;
	size_t length;
} KVChunkTranslator_key_t;

typedef struct {
	yajl_handle parser;
	yajl_gen generator;
	char *path;
	
	KVChunkTranslator_key_t **keyStack;
	size_t keyStackSize;
} KVChunkTranslator_ctx_t;

@interface KVChunkTranslator : NSObject
{
	yajl_callbacks _parser_callbacks;
	yajl_handle _parser;
	yajl_gen _generator;
	
	KVChunkTranslator_ctx_t _ctx;
}

@property (nonatomic, strong) NSString *path;

- (id)initWithPathForReporting:(NSString *)path;
- (NSData *)receivedChunk:(NSData *)chunk;

@end
