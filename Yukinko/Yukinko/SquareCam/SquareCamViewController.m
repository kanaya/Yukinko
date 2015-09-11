// THIS WORK IS BASED ON APPLE'S SquareCam //

/*
     File: SquareCamViewController.m
 Abstract: Dmonstrates iOS 5 features of the AVCaptureStillImageOutput class
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import "SquareCamViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>

#pragma mark-

static CGFloat DegreesToRadians(CGFloat degrees) {
  return degrees * M_PI / 180;
}

#pragma mark-

@interface UIImage (RotationMethods)
- (UIImage *)imageRotatedByDegrees: (CGFloat)degrees;
@end

@implementation UIImage (RotationMethods)

- (UIImage *)imageRotatedByDegrees: (CGFloat)degrees {
	// calculate the size of the rotated view's containing box for our drawing space
	UIView *rotatedViewBox = [[UIView alloc] initWithFrame: CGRectMake(0, 0, self.size.width, self.size.height)];
	CGAffineTransform t = CGAffineTransformMakeRotation(DegreesToRadians(degrees));
	rotatedViewBox.transform = t;
	CGSize rotatedSize = rotatedViewBox.frame.size;
	[rotatedViewBox release];
	
	// Create the bitmap context
	UIGraphicsBeginImageContext(rotatedSize);
	CGContextRef bitmap = UIGraphicsGetCurrentContext();
	
	// Move the origin to the middle of the image so we will rotate and scale around the center.
	CGContextTranslateCTM(bitmap, rotatedSize.width / 2, rotatedSize.height / 2);
	
	//   // Rotate the image context
	CGContextRotateCTM(bitmap, DegreesToRadians(degrees));
	
	// Now, draw the rotated/scaled image into the context
	CGContextScaleCTM(bitmap, 1.0, -1.0);
	CGContextDrawImage(bitmap, CGRectMake(-self.size.width / 2, -self.size.height / 2, self.size.width, self.size.height), [self CGImage]);
	
	UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return newImage;
}

@end

#pragma mark-

@interface SquareCamViewController (InternalMethods)
- (void)setupAVCapture;
- (void)teardownAVCapture;
@end

@implementation SquareCamViewController

- (void)setupAVCapture {
	AVCaptureSession *session = [AVCaptureSession new];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
	    [session setSessionPreset: AVCaptureSessionPreset640x480];
	else
	    [session setSessionPreset: AVCaptureSessionPresetPhoto];
	
  // Select a video device, make an input
	AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType: AVMediaTypeVideo];
  NSError *error = nil;
	AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice: device
                                                                            error: &error];
	require(error == nil, bail);
	
  isUsingFrontFacingCamera = NO;
	if ([session canAddInput: deviceInput])
		[session addInput: deviceInput];

  // Make a video data output
	videoDataOutput = [AVCaptureVideoDataOutput new];
	
  // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
  NSDictionary *rgbOutputSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey: @(kCMPixelFormat_32BGRA) };
	[videoDataOutput setVideoSettings: rgbOutputSettings];
	[videoDataOutput setAlwaysDiscardsLateVideoFrames: YES];
  // discard if the data output queue is blocked (as we process the still image)
    
  // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
  // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
  // see the header doc for setSampleBufferDelegate:queue: for more information
	videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
	[videoDataOutput setSampleBufferDelegate: self
                                     queue: videoDataOutputQueue];
  // Calls captureOutput:didOutputSampleBuffer:fromConnection:
	
  if ([session canAddOutput: videoDataOutput])
		[session addOutput: videoDataOutput];
	[[videoDataOutput connectionWithMediaType: AVMediaTypeVideo] setEnabled: NO];
	
	previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession: session];
  // [previewLayer setBackgroundColor: [[UIColor blueColor] CGColor]];  // ng ???
	[previewLayer setVideoGravity: AVLayerVideoGravityResizeAspect];
	CALayer *rootLayer = [previewView layer];
  [rootLayer setBackgroundColor: [UIColor blueColor].CGColor];  // ng ???
	[rootLayer setMasksToBounds: YES];
	[previewLayer setFrame: [rootLayer bounds]];
	[rootLayer addSublayer: previewLayer];
	[session startRunning];

  bail:
	[session release];
	if (error) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: [NSString stringWithFormat: @"Failed with error %d", (int)[error code]]
                                                        message: [error localizedDescription]
                                                       delegate: nil
                                              cancelButtonTitle: @"Dismiss"
                                              otherButtonTitles: nil];
		[alertView show];
		[alertView release];
		[self teardownAVCapture];
	}
}

// clean up capture setup
- (void)teardownAVCapture {
	[videoDataOutput release];
	if (videoDataOutputQueue)
		dispatch_release(videoDataOutputQueue);
	[stillImageOutput removeObserver: self
                        forKeyPath: @"isCapturingStillImage"];
	[stillImageOutput release];
	[previewLayer removeFromSuperlayer];
	[previewLayer release];
}

// utility routing used during image capture to set up capture orientation
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation: (UIDeviceOrientation)deviceOrientation {
	AVCaptureVideoOrientation result = (AVCaptureVideoOrientation)deviceOrientation;
	if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
		result = AVCaptureVideoOrientationLandscapeRight;
	else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
		result = AVCaptureVideoOrientationLandscapeLeft;
	return result;
}

// utility routine to display error aleart if takePicture fails
- (void)displayErrorOnMainQueue: (NSError *)error withMessage: (NSString *)message {
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: [NSString stringWithFormat:@"%@ (%d)", message, (int)[error code]]
                                                        message: [error localizedDescription]
                                                       delegate: nil
                                              cancelButtonTitle: @"Dismiss"
                                              otherButtonTitles: nil];
    [alertView show];
		[alertView release];
  });
}

- (IBAction)takePicture: (id)sender {
  // Here we go.
  if (facialImages) {
    // NSLog(@"Snap (%d)", facialImages.count);
    for (int i = 0; i < facialImages.count; ++i) {
      CALayer *layer = [facialViewLayers objectAtIndex: i];
      UIImage *image = [facialImages objectAtIndex: i];
      layer.contents = (id)image.CGImage;
    }
    for (NSUInteger i = facialImages.count; i < 4; ++i) {
      CALayer *layer = [facialViewLayers objectAtIndex: i];
      layer.contents = NULL;
    }
  }
  else {
    for (int i = 0; i < 4; ++i) {
      CALayer *layer = [facialViewLayers objectAtIndex: i];
      layer.contents = NULL;
    }
  }
}

// turn on/off face detection
- (IBAction)toggleFaceDetection: (id)sender {
	detectFaces = [(UISwitch *)sender isOn];
	[[videoDataOutput connectionWithMediaType: AVMediaTypeVideo] setEnabled: detectFaces];
}

// THIS IS A DELEGATE METHOD
- (void)captureOutput: (AVCaptureOutput *)captureOutput didOutputSampleBuffer: (CMSampleBufferRef)sampleBuffer fromConnection: (AVCaptureConnection *)connection {
	// got an image
	CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
	CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer: pixelBuffer
                                                    options: (NSDictionary *)attachments];

	if (attachments)
		CFRelease(attachments);
	NSDictionary *imageOptions = nil;
	UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
	int exifOrientation;
	
    /* kCGImagePropertyOrientation values
        The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
        by the TIFF and EXIF specifications -- see enumeration of integer constants. 
        The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
        
        used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
        If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
        
	enum {
		PHOTOS_EXIF_0ROW_TOP_0COL_LEFT     = 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
		PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT    = 2, //   2  =  0th row is at the top, and 0th column is on the right.
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT  = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
		PHOTOS_EXIF_0ROW_LEFT_0COL_TOP     = 5, //   5  =  0th row is on the left, and 0th column is the top.
		PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP    = 6, //   6  =  0th row is on the right, and 0th column is the top.
		PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
		PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM  = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
	};
	
	switch (curDeviceOrientation) {
		case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
			exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
			break;
		case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
			if (isUsingFrontFacingCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			break;
		case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
			if (isUsingFrontFacingCamera)
				exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			else
				exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
			break;
		case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
		default:
			exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
			break;
	}
  imageOptions = @{ CIDetectorImageOrientation: @(exifOrientation) };
	NSArray *features = [faceDetector featuresInImage: ciImage
                                            options: imageOptions];

  // HERE WE GO.
  if (features.count > 0) {
    NSMutableArray *_facialImages = [NSMutableArray arrayWithCapacity: features.count];
    // Let's gate CGImage from CMSampleBuffer
    CIContext *ciContext = [CIContext contextWithOptions: nil]; // can go out of the loop?
    for (CIFaceFeature *ff in features) {
      CGRect faceRect = ff.bounds;
      NSLog(@"faceRect == (%f, %f), (%f, %f)", faceRect.origin.x, faceRect.origin.y, faceRect.size.width, faceRect.size.height);
      CGImageRef cgImage = [ciContext createCGImage: ciImage
                                           fromRect: faceRect];
      UIImage *uiImage = [[UIImage imageWithCGImage: cgImage] retain];  // retain???
      [_facialImages addObject: uiImage];
    }
    if (facialImages) {
      facialImages = nil;
    }
    facialImages = [[NSArray arrayWithArray: _facialImages] retain];
  }
  else {
    if (facialImages) {
      facialImages = nil;
    }
  }
  [ciImage release];
}

- (void)dealloc {
	[self teardownAVCapture];
	[faceDetector release];
	[super dealloc];
}

// use front/back camera
- (IBAction)switchCameras: (id)sender {
	AVCaptureDevicePosition desiredPosition;
	if (isUsingFrontFacingCamera)
		desiredPosition = AVCaptureDevicePositionBack;
	else
		desiredPosition = AVCaptureDevicePositionFront;
	
	for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType: AVMediaTypeVideo]) {
		if ([d position] == desiredPosition) {
			[[previewLayer session] beginConfiguration];
			AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice: d error: nil];
			for (AVCaptureInput *oldInput in [[previewLayer session] inputs]) {
				[[previewLayer session] removeInput: oldInput];
			}
			[[previewLayer session] addInput: input];
			[[previewLayer session] commitConfiguration];
			break;
		}
	}
	isUsingFrontFacingCamera = !isUsingFrontFacingCamera;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];

	// Do any additional setup after loading the view, typically from a nib.
	[self setupAVCapture];

  NSDictionary *detectorOptions = @{ CIDetectorAccuracy: CIDetectorAccuracyLow };
	faceDetector = [[CIDetector detectorOfType: CIDetectorTypeFace
                                     context: nil
                                     options: detectorOptions] retain];

  NSMutableArray *_facialViewLayers = [NSMutableArray arrayWithCapacity: 4];
  NSArray *facialViews = @[ facialView0, facialView1, facialView2, facialView3 ];
  int i = 0;
  for (UIView *facialView in facialViews) {
    CALayer *facialLayer = [[CALayer layer] retain];
    facialLayer.backgroundColor = [UIColor yellowColor].CGColor;
    facialLayer.bounds = facialView.bounds;
    facialLayer.frame = facialView.bounds; // ???
    [facialView.layer addSublayer: facialLayer];
    [_facialViewLayers insertObject: facialLayer
                            atIndex: i];
    ++i;
  }
  facialViewLayers = [[NSArray arrayWithArray: _facialViewLayers] retain];

  facialImages = nil;
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear: animated];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear: animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation {
  // Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
