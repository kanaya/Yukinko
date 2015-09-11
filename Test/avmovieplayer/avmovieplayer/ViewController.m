//
//  ViewController.m
//  avmovieplayer
//
//  Created by Ichi Kanaya on 9/11/15.
//  Copyright © 2015 Pinapple. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.

  NSBundle *mainBundle = [NSBundle mainBundle];
  NSURL *movieURL = [mainBundle URLForResource: @"alpaca-background" withExtension: @"mov"];
  NSLog(@"%@", movieURL);
  AVPlayer *player = [AVPlayer playerWithURL: movieURL];
  AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer: player];
  playerLayer.frame = self.view.frame;
  // playerLayer.bounds = self.view.bounds;
  NSLog(@"frame = (%f, %f, %f, %f); bounds = (%f, %f, %f, %f)", self.view.frame.origin.x, self.view.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height, self.view.bounds.origin.x, self.view.bounds.origin.y, self.view.bounds.size.width, self.view.bounds.size.height);

  UIImage *maskImage = [UIImage imageNamed: @"testmask.png"];
  CALayer *maskLayer = [CALayer layer];
  maskLayer.contents = (id)maskImage.CGImage;
  maskLayer.frame = playerLayer.frame;
  // maskLayer.position = CGPointZero;

  playerLayer.mask = maskLayer;

  CALayer *rootLayer = self.view.layer;
  [rootLayer addSublayer: playerLayer];
  [player play];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.

}

@end
