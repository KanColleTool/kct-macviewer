//
//  KVUserDataFileHandle.h
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-05-23.
//  Copyright (c) 2014 KanColleTool. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * An utility class for writing to a temporary file and moving it to a
 * permanent location afterwards.
 *
 * The file handle is lazy-loaded, and the underlying file will be created
 * as needed using the POSIX safe temporary file functions. Call
 * -[closeAndOverwrite] on the handle to overwrite the destination with
 * the temporary file.
 * 
 * These handles can be reused - they will create a new temporary file if
 * the old one has already been closed.
 */

@interface KVTempFileHandle : NSObject
{
	NSString *_tempPath;
	NSFileHandle *_fileHandle;
}

@property (nonatomic, readonly) NSString *destPath;
@property (nonatomic, readonly) NSFileHandle *fileHandle;

/**
 * Creates a handle with the destination set to the specified path.
 */
- (id)initWithDestPath:(NSString *)destPath;

/**
 * Closes the file handle and overwrites the destination path with the
 * temporary file. If the destination file (or any part of the path leading
 * up to it) doesn't exist, an attempt will be made to create them.
 */
- (void)closeAndOverwrite:(NSError **)error;

@end
