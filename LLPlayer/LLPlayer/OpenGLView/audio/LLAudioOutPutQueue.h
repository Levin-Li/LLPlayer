//
//  LLAudioOutPutQueue.h
//  MCAudioInputQueue
//
//  Created by mac on 2016/12/19.
//  Copyright © 2016年 Chengyin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface LLAudioOutPutQueue : NSObject
@property(nonatomic, assign) AudioQueueRef outputQueue;
@property(nonatomic, assign) UInt32 bufferSize;
//一个buffer保存多久的录音时间(默认为0.2秒生成的大小)
@property (nonatomic,assign,readonly) NSTimeInterval bufferDuration;

@property(nonatomic, strong) NSMutableArray *receiveData;

-(void)registAudio:(AudioStreamBasicDescription )audioFormat;

@end
