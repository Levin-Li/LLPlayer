//
//  LLAudioPcm.h
//  LLPlayer
//
//  Created by mac on 2016/12/16.
//  Copyright © 2016年 luolei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface LLAudioPcm : NSObject
@property(nonatomic, assign) AudioQueueRef outputQueue;
@property(nonatomic, assign) UInt32 bufferSize;
@property(nonatomic, strong) NSMutableArray *receiveData;

-(void)registAudio:(AudioStreamBasicDescription )audioFormat;
@end
