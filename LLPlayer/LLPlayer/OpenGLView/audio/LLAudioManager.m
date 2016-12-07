//
//  LLAudioManager.m
//  LLPlayer
//
//  Created by mac on 2016/12/7.
//  Copyright © 2016年 luolei. All rights reserved.
//

#import "LLAudioManager.h"
#import <AudioToolbox/AudioToolbox.h>
// Invoked when an audio interruption in iOS begins or ends.
typedef void (*AudioSessionInterruptionListener)( void *inClientData, UInt32 inInterruptionState );

@implementation LLAudioManager

//-(void)playAudioAAC
//{
//    AudioSessionInitialize(NULL,
//                           kCFRunLoopCommonModes,
//                           sessionInterruptionListener,
//                           (__bridge void *) (self)
//}

#pragma mark - Audio Session Callback
                           
                           void inInterruptionListener(void *inClientData, UInt32 inInterruptionState) {
                               switch (inInterruptionState) {
                                   case kAudioSessionBeginInterruption:
                                       printf("interruption state kAudioSessionBeginInterruption\n");
                                       break;
                                   case kAudioSessionEndInterruption:
                                       printf("interruption state kAudioSessionEndInterruption\n");
                                       break;
                                   default:
                                       printf("Unkown interruption state\n");
                                       break;
                               }
                           }

#pragma mark - Audio Session

- (void)setupAudioSession {
    OSStatus status = AudioSessionInitialize(NULL,
                                             kCFRunLoopDefaultMode,
                                             inInterruptionListener,
                                             (__bridge void *)self);
    if (kAudioSessionNoError != status) {
        printf("AudioSessionInitialize failed with %ld", status);
    }
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    status = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                                     sizeof(sessionCategory), 
                                     &sessionCategory);
    
    AudioSessionSetActive(true);
}

#pragma mark - Audio Unit Callback

OSStatus renderCallback(void *inRefCon,
                        AudioUnitRenderActionFlags *ioActionFlags,
                        const AudioTimeStamp *inTimeStamp,
                        UInt32 inBusNumber,
                        UInt32 inNumberFrames,
                        AudioBufferList *ioData) {
    // 静音
    for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    // 下面填充实际的音频数据
    // ...
    return kAudioSessionNoError;
}

#pragma mark - Audio Unit

- (void)setupAudioUnit {
    AudioComponentDescription audioComponentDescription = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_RemoteIO,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        0};
    AudioComponent audioComponent = AudioComponentFindNext(NULL,
                                                           &audioComponentDescription);
    if (!audioComponent) {
        printf("audioComponent == NULL\n");
    }
    AudioComponentInstance componentInstance = NULL;
    AudioComponentInstanceNew(audioComponent, &componentInstance);
    
    AudioStreamBasicDescription outputFormat;
    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioUnitGetProperty(componentInstance,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &outputFormat,
                         &size);
    outputFormat.mSampleRate = 441000;
    AudioUnitSetProperty(componentInstance,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &outputFormat, size);
    
    AURenderCallbackStruct renderCallbackRef = {
        .inputProc = renderCallback,
        .inputProcRefCon = (__bridge void *) (self)};
    AudioUnitSetProperty(componentInstance,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         0, 
                         &renderCallbackRef, 
                         sizeof(renderCallbackRef));
    
    OSStatus status = AudioUnitInitialize(componentInstance);
    NSLog(@"status = %ld", status);
    AudioOutputUnitStart(componentInstance);
}

-(void)startPlayAudio
{
    AudioStreamBasicDescription streamFormat = {
        .mSampleRate        = 441000,
        .mFormatID            = kAudioFormatMPEG4AAC,
        .mFormatFlags        = kAudioFormatFlagIsFloat,
        .mFramesPerPacket    = 1,
        .mChannelsPerFrame    = 2,
        .mBitsPerChannel    = 16,
        .mBytesPerPacket    = 2 * sizeof (Float32),
        .mBytesPerFrame        = 2 * sizeof (Float32)};
}

@end
