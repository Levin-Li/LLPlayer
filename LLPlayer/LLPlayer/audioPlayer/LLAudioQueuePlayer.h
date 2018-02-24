//
//  LLAudioQueuePlayer.h
//  LLPlayer
//
//  Created by luo luo on 23/10/2017.
//  Copyright © 2017 luolei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define kXDXRecoderAACFramesPerPacket       1024

@interface LLAudioQueuePlayer : NSObject
//接收录音数据的数组，本用来放入播放队列
@property(nonatomic,strong) NSMutableArray *receiveData;

-(void)setAudioFormat:(AudioStreamBasicDescription )format;

+ (instancetype)sharedInstance;
//开始播放
-(void)startPlay;
-(void)stop;
@end
