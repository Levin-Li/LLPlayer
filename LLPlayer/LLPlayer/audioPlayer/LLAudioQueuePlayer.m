//
//  LLAudioQueuePlayer.m
//  LLPlayer
//
//  Created by luo luo on 23/10/2017.
//  Copyright © 2017 luolei. All rights reserved.
//

#import "LLAudioQueuePlayer.h"

/**
 *  缓存区的个数，一般3个
 */
#define kNumberAudioQueueBuffers 3
#define kDefaultSampleRate 48000.0
#define kRecoderConverterEncodeBitRate   64000 //码率和采样率对应
#define kDefaultOutputBufferSize 1024*7 //7040
@interface LLAudioQueuePlayer()
@property (assign, nonatomic) AudioQueueRef                 outputQueue;

@end

@implementation LLAudioQueuePlayer{
    AudioStreamBasicDescription     _audioFormat;//存放音频格式
    AudioQueueBufferRef     _outputBuffers[kNumberAudioQueueBuffers];
}

+ (instancetype)sharedInstance {
    static LLAudioQueuePlayer *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[LLAudioQueuePlayer alloc] init];
    });
    
    return manager;
}

-(NSMutableArray *)receiveData
{
    if (!_receiveData) {
        _receiveData = [[NSMutableArray alloc]init];
    }
    return _receiveData;
}

#pragma mark 回调
// 输出回调---如需播放把如下打开
void GenericPlayCallback (
                          void                 *inUserData,
                          AudioQueueRef        inAQ,
                          AudioQueueBufferRef  inBuffer
                          )
{
    
    
    LLAudioQueuePlayer *manage = (__bridge LLAudioQueuePlayer *)(inUserData);
//    NSLog(@"播放回调现有数据包:%d",(int)manage.receiveData.count);
    if([manage.receiveData count] >0)
    {
        NSData *pcmData ;//= [manage.receiveData objectAtIndex:0];
        pcmData = [manage.receiveData objectAtIndex:0];
        NSLog(@"播放数据长度为＝%lu",(unsigned long)pcmData.length);
        
        if(pcmData && pcmData.length < 10000){
            memcpy(inBuffer->mAudioData, pcmData.bytes, pcmData.length);//将数据拷贝到缓存
            inBuffer->mAudioDataByteSize = (UInt32)pcmData.length;
            inBuffer->mPacketDescriptionCount = 0;
        }
        
        //测试播放
        [manage.receiveData removeObjectAtIndex:0];
        //@end
        
    }
    else
    {
        makeSilent2(inBuffer);
    }
    AudioQueueEnqueueBuffer(manage.outputQueue,inBuffer,0,NULL);
}

#pragma mark 转码
//-(NSData *)getPcmData:(NSData *)aacdata
//{
//    Byte pcmbyte[7000];
//    unsigned int pcmdataSize;
//    memset(pcmbyte, 0, sizeof(pcmbyte));
//    AACDFFmpeg *pegCtx =  aac_decoder_create(kDefaultSampleRate, _audioFormat.mChannelsPerFrame, kRecoderConverterEncodeBitRate);
//    int success =  aac_decode_frame(pegCtx, (Byte *)[aacdata bytes], (int)aacdata.length, pcmbyte, &pcmdataSize);
//
//    if (success == 0) {
//        NSData *pcmData = [NSData dataWithBytes:pcmbyte length:pcmdataSize];
//        NSLog(@"解码成功pmcDataSize:%d",pcmdataSize);
//        return pcmData;
//    }else{
//        NSLog(@"解码失败:%d",pcmdataSize);
//    }
//
//    return nil;
//}

//开始播放
-(void)startPlay
{
    //设置播放的参数
    //    [self setupAudioFormat];
    
    //创建一个输出队列
    AudioQueueNewOutput(&_audioFormat, GenericPlayCallback, (__bridge void *) self, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, 0,&_outputQueue);
    
    // 创建并分配缓冲区空间 4个缓冲区
    for (int i = 0; i<kNumberAudioQueueBuffers; ++i)
    {
        AudioQueueAllocateBuffer(_outputQueue, kDefaultOutputBufferSize, &_outputBuffers[i]);
        makeSilent2(_outputBuffers[i]);  //改变数据
        //插入Buttf
        AudioQueueEnqueueBuffer(_outputQueue,_outputBuffers[i],0,NULL);
    }
    Float32 gain = 1.0;                                       // 1
    // Optionally, allow user to override gain setting here 设置音量
    AudioQueueSetParameter (_outputQueue,kAudioQueueParam_Volume,gain);
    
    //开启播放队列
    AudioQueueStart(_outputQueue,NULL);
}

-(void)stop
{
    AudioQueueStop ( self.outputQueue,true);
    AudioQueueDispose (self.outputQueue, true );//并且
}


- (void)setupAudioFormat
{
    //重置下
    memset(&_audioFormat, 0, sizeof(_audioFormat));
    
    //采样率的意思是每秒需要采集的帧数
    _audioFormat.mSampleRate = kDefaultSampleRate;//[[AVAudioSession sharedInstance] sampleRate];
    
    //设置通道数,这里先使用系统的测试下 //TODO:
    _audioFormat.mChannelsPerFrame = 1;//(UInt32)[[AVAudioSession sharedInstance] inputNumberOfChannels];
    
    //设置format，怎么称呼不知道。
    _audioFormat.mFormatID = kAudioFormatLinearPCM;
    
    if (_audioFormat.mFormatID == kAudioFormatLinearPCM){
        //这个屌属性不知道干啥的。，
        _audioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        //每个通道里，一帧采集的bit数目
        _audioFormat.mBitsPerChannel = 16;
        //结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte数目。
        //所以这里结果赋值给每帧需要采集的byte数目，然后这里的packet也等于一帧的数据。
        //至于为什么要这样。。。不知道。。。
        _audioFormat.mBytesPerPacket = _audioFormat.mBytesPerFrame = (_audioFormat.mBitsPerChannel / 8) * _audioFormat.mChannelsPerFrame;
        _audioFormat.mFramesPerPacket = 1;
    }
}

-(void)setAudioFormat:(AudioStreamBasicDescription )format
{
    memset(&_audioFormat, 0, sizeof(_audioFormat));
    memcpy(&_audioFormat, &format, sizeof(format));
    
}


//把缓冲区置空 静音
static inline void makeSilent2(AudioQueueBufferRef buffer)
{
    for (int i=0; i < buffer->mAudioDataBytesCapacity; i++) {
        buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
        UInt8 * samples = (UInt8 *) buffer->mAudioData;
        samples[i]=0;
    }
}

@end
