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
  playerLayer.bounds = self.view.bounds;
  CALayer *rootLayer = self.view.layer;
  [rootLayer addSublayer: playerLayer];
  [player play];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.

}

@end
