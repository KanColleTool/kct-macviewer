//
//  KVUserDataFileHandle.m
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-05-23.
//  Copyright (c) 2014 KanColleTool. All rights reserved.
//

#import "KVTempFileHandle.h"

@implementation KVTempFileHandle

- (id)initWithDestPath:(NSString *)destPath
{
	if((self = [super init]))
	{
		_destPath = destPath;
	}
	
	return self;
}

- (void)dealloc
{
	[_fileHandle closeFile];
}

- (NSFileHandle *)fileHandle
{
	if(!_fileHandle)
	{
		NSString *template = [NSTemporaryDirectory() stringByAppendingPathComponent:@"UserDataStoreTmp.XXXXXXXX"];
		const char *templateFSRep = [template fileSystemRepresentation];
		char *templateCString = strdup(templateFSRep);
		int fd = mkstemp(templateCString);
		
		_tempPath = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:templateCString length:strlen(templateCString)];
		_fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:NO];
		
		free(templateCString);
	}
	
	return _fileHandle;
}

- (void)closeAndOverwrite:(NSError *__autoreleasing *)error
{
	// Do nothing if the handle has already been closed, and a new file hasn't been
	// created since (and nothing has thus been written to it either).
	if(!_fileHandle || !_tempPath)
		return;
	
	[_fileHandle closeFile];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	if([fm createDirectoryAtPath:[_destPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:error])
	{
		if([fm fileExistsAtPath:_destPath])
		{
			NSFileHandle *src = [NSFileHandle fileHandleForReadingAtPath:_tempPath];
			NSFileHandle *dst = [NSFileHandle fileHandleForWritingAtPath:_destPath];
			
			[dst truncateFileAtOffset:0];
			
			NSData *buffer = nil;
			while(true)
			{
				buffer = [src readDataOfLength:1024*4];
				if([buffer length] > 0)
					[dst writeData:buffer];
				else
					break;
			}
		}
		else
		{
			[fm moveItemAtPath:_tempPath toPath:_destPath error:error];
		}
	}
	
	_fileHandle = nil;
	_tempPath = nil;
}

@end
