//
//  GLView.m
//  GraphicsExample
//
//  Created by Kai on 11/2/12.
//  Copyright (c) 2012 Kai. All rights reserved.
//

#import "NSGLView.h"
#import <OpenGL/OpenGL.h>
#import <QuartzCore/CVDisplayLink.h>


@interface NSGLView()
{
    CGLContextObj _glContext;
    CGLPixelFormatObj _pixelObj;
    
	CVDisplayLinkRef _displayLink;
    
}
- (void) drawView;

@end
@implementation NSGLView


- (CVReturn) getFrameForTime:(const CVTimeStamp*)outputTime
{
	// There is no autorelease pool when this method is called
	// because it will be called from a background thread
	// It's important to create one or you will leak objects
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self drawView];
	
	[pool release];
	return kCVReturnSuccess;
}

// This is the renderer output callback function
static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
{
    CVReturn result = [(NSGLView*)displayLinkContext getFrameForTime:outputTime];
    return result;
}

- (void) awakeFromNib
{
    // Make all the OpenGL calls to setup rendering
	//  and build the necessary rendering objects
    
    GLint npix;
    
    CGLPixelFormatAttribute attribs[] = {
        kCGLPFADoubleBuffer,
        kCGLPFADepthSize,  (CGLPixelFormatAttribute)24,
        (CGLPixelFormatAttribute)0 };
    
    CGLChoosePixelFormat(attribs, &_pixelObj, &npix);
    CGLCreateContext(_pixelObj, NULL, &_glContext);
    
	
	NSOpenGLPixelFormat *pf = [[[NSOpenGLPixelFormat alloc] initWithCGLPixelFormatObj:_pixelObj] autorelease];
    NSOpenGLContext* context = [[[NSOpenGLContext alloc] initWithCGLContextObj:_glContext] autorelease];
    
    [self setPixelFormat:pf];
    
    [self setOpenGLContext:context];
}

- (void) prepareOpenGL
{
	[super prepareOpenGL];
    
    // Make this openGL context current to the thread
	// (i.e. all openGL on this thread calls will go to this context)
	[[self openGLContext] makeCurrentContext];
	
	// Synchronize buffer swaps with vertical refresh rate
	GLint swapInt = 1;
	[[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
	
	// Create a display link capable of being used with all active displays
	CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
	
	// Set the renderer output callback function
	CVDisplayLinkSetOutputCallback(_displayLink, &MyDisplayLinkCallback, self);
	
	// Set the display link for the current renderer
	CGLContextObj cglContext = (CGLContextObj)[[self openGLContext] CGLContextObj];
	CGLPixelFormatObj cglPixelFormat = (CGLPixelFormatObj)[[self pixelFormat] CGLPixelFormatObj];
	CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_displayLink, cglContext, cglPixelFormat);
	
	// Activate the display link
	CVDisplayLinkStart(_displayLink);
}


- (void) reshape
{
	[super reshape];
	
	// We draw on a secondary thread through the display link
	// When resizing the view, -reshape is called automatically on the main thread
	// Add a mutex around to avoid the threads accessing the context simultaneously when resizing
	CGLLockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
	
	CGLUnlockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
}

- (void) drawView
{
	[[self openGLContext] makeCurrentContext];
    
	// We draw on a secondary thread through the display link
	// When resizing the view, -reshape is called automatically on the main thread
	// Add a mutex around to avoid the threads accessing the context simultaneously	when resizing
	CGLLockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
    
    // Draw here
    glClearColor(0,0,0,0);
    glClear(GL_COLOR_BUFFER_BIT);
    
	CGLFlushDrawable((CGLContextObj)[[self openGLContext] CGLContextObj]);
	CGLUnlockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
}

- (void) dealloc
{
	// Stop the display link BEFORE releasing anything in the view
    // otherwise the display link thread may call into the view and crash
    // when it encounters something that has been release
	CVDisplayLinkStop(_displayLink);
    
	CVDisplayLinkRelease(_displayLink);
    
	// Release the display link AFTER display link has been released	
	[super dealloc];
}

@end
