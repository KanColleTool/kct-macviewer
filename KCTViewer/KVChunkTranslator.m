//
//  KVChunkTranslator.m
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-05-02.
//  Copyright (c) 2014 KanColleTool. All rights reserved.
//

#import "KVChunkTranslator.h"
#import "KVTranslator.h"

int KVChunkTranslator_cb_null(void *_ctx) { return yajl_gen_null(((KVChunkTranslator_ctx_t*)_ctx)->generator) == yajl_gen_status_ok; }
int KVChunkTranslator_cb_boolean(void *_ctx, int val) { return yajl_gen_bool(((KVChunkTranslator_ctx_t*)_ctx)->generator, val) == yajl_gen_status_ok; }
int KVChunkTranslator_cb_number(void *_ctx, const char *val, size_t len) { return yajl_gen_number(((KVChunkTranslator_ctx_t*)_ctx)->generator, val, len) == yajl_gen_status_ok; }
int KVChunkTranslator_cb_start_array(void *_ctx) { return yajl_gen_array_open(((KVChunkTranslator_ctx_t*)_ctx)->generator) == yajl_gen_status_ok; }
int KVChunkTranslator_cb_end_array(void *_ctx) { return yajl_gen_array_close(((KVChunkTranslator_ctx_t*)_ctx)->generator) == yajl_gen_status_ok; }

int KVChunkTranslator_cb_start_map(void *_ctx)
{
	KVChunkTranslator_ctx_t *ctx = ((KVChunkTranslator_ctx_t*)_ctx);
	++ctx->keyStackSize;
	if(ctx->keyStack == NULL) ctx->keyStack = malloc(sizeof(KVChunkTranslator_key_t)*ctx->keyStackSize);
	else ctx->keyStack = realloc(ctx->keyStack, sizeof(KVChunkTranslator_key_t*)*ctx->keyStackSize);
	ctx->keyStack[ctx->keyStackSize-1] = calloc(1, sizeof(KVChunkTranslator_key_t));
	return yajl_gen_map_open(ctx->generator) == yajl_gen_status_ok;
}

int KVChunkTranslator_cb_end_map(void *_ctx)
{
	KVChunkTranslator_ctx_t *ctx = ((KVChunkTranslator_ctx_t*)_ctx);
	free(ctx->keyStack[ctx->keyStackSize-1]);
	--ctx->keyStackSize;
	// No need to realloc to shrink here, really
	return yajl_gen_map_close(ctx->generator) == yajl_gen_status_ok;
}
int KVChunkTranslator_cb_map_key(void *_ctx, const unsigned char *key, size_t len)
{
	KVChunkTranslator_ctx_t *ctx = ((KVChunkTranslator_ctx_t*)_ctx);
	ctx->keyStack[ctx->keyStackSize-1]->key = key;
	ctx->keyStack[ctx->keyStackSize-1]->length = len;
	return yajl_gen_string(ctx->generator, key, len) == yajl_gen_status_ok;
}

int KVChunkTranslator_cb_string(void *_ctx, const unsigned char *val, size_t len)
{
	KVChunkTranslator_ctx_t *ctx = ((KVChunkTranslator_ctx_t*)_ctx);
	NSString *nsstr = [[NSString alloc] initWithBytes:val length:len encoding:NSUTF8StringEncoding];
	NSString *nspath = [[NSString alloc] initWithUTF8String:ctx->path];
	NSString *nskey = (ctx->keyStackSize != 0 ? [[NSString alloc] initWithBytes:ctx->keyStack[ctx->keyStackSize-1]->key length:ctx->keyStack[ctx->keyStackSize-1]->length encoding:NSUTF8StringEncoding] : NULL);
	NSString *tlstr = [[KVTranslator sharedTranslator] translate:nsstr pathForReporting:nspath key:nskey];
	return yajl_gen_string(ctx->generator, (const unsigned char*)[tlstr UTF8String], [tlstr lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) == yajl_gen_status_ok;
}

@implementation KVChunkTranslator

- (id)initWithPathForReporting:(NSString *)path
{
	if((self = [super init]))
	{
		_parser_callbacks.yajl_null = &KVChunkTranslator_cb_null;
		_parser_callbacks.yajl_boolean = &KVChunkTranslator_cb_boolean;
		_parser_callbacks.yajl_number = &KVChunkTranslator_cb_number;
		_parser_callbacks.yajl_string = &KVChunkTranslator_cb_string;
		_parser_callbacks.yajl_start_map = &KVChunkTranslator_cb_start_map;
		_parser_callbacks.yajl_map_key = &KVChunkTranslator_cb_map_key;
		_parser_callbacks.yajl_end_map = &KVChunkTranslator_cb_end_map;
		_parser_callbacks.yajl_start_array = &KVChunkTranslator_cb_start_array;
		_parser_callbacks.yajl_end_array = &KVChunkTranslator_cb_end_array;
		
		_generator = yajl_gen_alloc(NULL);
		_parser = yajl_alloc(&_parser_callbacks, NULL, &_ctx);
		
		_ctx.parser = _parser;
		_ctx.generator = _generator;
		_ctx.path = strdup([path UTF8String]);
		_ctx.keyStack = NULL;
		_ctx.keyStackSize = 0;
	}
	
	return self;
}

- (void)dealloc
{
	yajl_free(_parser);
	yajl_gen_free(_generator);
	free(_ctx.path);
	
	if(_ctx.keyStack != NULL)
		free(_ctx.keyStack);
}

- (NSData *)receivedChunk:(NSData *)chunk
{
	const unsigned char *text = [chunk bytes];
	size_t size = [chunk length];
	
	// Skip UTF-8 BOM if present
	const char bom[] = {0xEF, 0xBB, 0xBF};
	if(memcmp(bom, text, 3) == 0)
	{
		text += 3;
		size -= 3;
	}
	
	// Skip, but acknowledge, a "svdata=" (the game needs it prepended to work)
	bool had_prefix = false;
	const char *prefix = "svdata=";
	if(memcmp(prefix, text, strlen(prefix)) == 0)
	{
		text += strlen(prefix);
		size -= strlen(prefix);
		had_prefix = true;
	}
	
	if(size > 0)
	{
		yajl_status parse_status = yajl_parse(_parser, text, size);
		if(parse_status != yajl_status_ok)
		{
			unsigned char *error = yajl_get_error(_parser, 1, text, size);
			NSLog(@"YAJL Error at %zu:\n%s", yajl_get_bytes_consumed(_parser), error);
			yajl_free_error(_parser, error);
			return nil;
		}
		
		const unsigned char *buf;
		size_t buf_len;
		yajl_gen_get_buf(_generator, &buf, &buf_len);
		
		if(buf_len > 0)
		{
			NSString *str = [[NSString alloc] initWithBytes:buf length:buf_len encoding:NSUTF8StringEncoding];
			yajl_gen_clear(_generator);
			
			if(had_prefix)
			{
				NSMutableData *data = [NSMutableData dataWithCapacity:strlen(prefix) + [str lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
				[data appendBytes:prefix length:strlen(prefix)];
				[data appendData:[str dataUsingEncoding:NSUTF8StringEncoding]];
				return data;
			}
			else
				return [str dataUsingEncoding:NSUTF8StringEncoding];
		}
	}
	
	return [NSData data];
}

@end
