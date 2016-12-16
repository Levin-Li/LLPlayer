//
//  LLAudioPcm.m
//  LLPlayer
//
//  Created by mac on 2016/12/16.
//  Copyright © 2016年 luolei. All rights reserved.
//

#import "LLAudioPcm.h"

#import <AVFoundation/AVFoundation.h>

/**
 *  缓存区的个数，一般3个
 */
#define kNumberAudioQueueBuffers 3

//每个buff保存多长时间的录音时间
static const NSTimeInterval bufferDuration = 0.2;

@interface LLAudioPcm()
{
    @private
//    UInt32 _bufferSize;
}
@property (nonatomic,assign,readonly) NSTimeInterval bufferDuration;
@end
@implementation LLAudioPcm{
//    AudioQueueRef                   _outputQueue;
    AudioStreamBasicDescription     _format;
    AudioQueueBufferRef     _outputBuffers[kNumberAudioQueueBuffers];
}

-(NSMutableArray *)receiveData
{
    if (!_receiveData) {
        _receiveData = [[NSMutableArray alloc]init];
    }
    return _receiveData;
}
-(void)registAudio:(AudioStreamBasicDescription )audioFormat
{
    //重置下
//    memset(&_audioFormat, 0, sizeof(_audioFormat));
    _format = audioFormat;
    _bufferDuration = bufferDuration;
    _bufferSize = _format.mBitsPerChannel * _format.mChannelsPerFrame * _format.mSampleRate * _bufferDuration / 8;

    //创建输出队列
        AudioQueueNewOutput(&_format, GenericOutputCallback, (__bridge void *) self, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, 0,&_outputQueue);
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    //默认情况下扬声器播放
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];

    
    
    //创建并分配缓冲区空间 4个缓冲区
        for (int i = 0; i<kNumberAudioQueueBuffers; ++i)
        {
            AudioQueueAllocateBuffer(_outputQueue, _bufferSize, &_outputBuffers[i]);
        }
        for (int i=0; i < kNumberAudioQueueBuffers; ++i) {
            makeSilent(_outputBuffers[i]);  //改变数据
            // 给输出队列完成配置
            AudioQueueEnqueueBuffer(_outputQueue,_outputBuffers[i],0,NULL);
        }
    
    Float32 gain = 1.0;                                       // 1
    // Optionally, allow user to override gain setting here 设置音量
    AudioQueueSetParameter (_outputQueue,kAudioQueueParam_Volume,gain);
    
    //开启播放队列
    AudioQueueStart(_outputQueue,NULL);
    
}

#pragma mark 回调
// 输出回调
void GenericOutputCallback (
                            void                 *inUserData,
                            AudioQueueRef        inAQ,
                            AudioQueueBufferRef  inBuffer
                            )
{
    LLAudioPcm *audio = (__bridge LLAudioPcm *)inUserData;
    if (audio.receiveData.count >0) {
        NSData *pcmData = [audio.receiveData objectAtIndex:0];
        NSLog(@"播放数据长度为=%lu",(unsigned long)pcmData.length);
        if (pcmData) {
            
            if (pcmData.length < audio.bufferSize) {
                memcpy(inBuffer->mAudioData, pcmData.bytes, pcmData.length);//将数据拷贝到缓存
                inBuffer->mAudioDataByteSize = (UInt32)pcmData.length;
                inBuffer->mPacketDescriptionCount = 0;
            }
        }else{
            makeSilent(inBuffer);
        }
    }
    
    AudioQueueEnqueueBuffer(audio.outputQueue, inBuffer, 0, NULL);
}

#pragma mark 其它
//把缓冲区置空
void makeSilent(AudioQueueBufferRef buffer)
{
    for (int i=0; i < buffer->mAudioDataBytesCapacity; i++) {
        buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
        UInt8 * samples = (UInt8 *) buffer->mAudioData;
        samples[i]=0;
    }
}

@end
