//
//  LLMediaDecoder.h
//  LLPlayer
//
//  Created by luo luo on 19/10/2017.
//  Copyright © 2017 luolei. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

# define LLLog(format, ...) NSLog((@"className:%@" "[line:%d]" format),NSStringFromClass([self class]),__LINE__, ##__VA_ARGS__);
//主线程
#define GCDMain(block)       dispatch_async(dispatch_get_main_queue(),block)
///GCD，获取一个全局队列
#define GCDBackground(block) dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block)
#define LLMinCacheDutation 10

typedef enum {
    LLMediaFrameTypeAudio,
    LLMediaFrameTypeVideo,
} LLMediaFrameType;

typedef enum {
    LLVideoFrameFormatYUV,
}LLVideoFrameFormat;

@class LLMediaDecoder;
@class LLVideoFrameYUV;
@protocol MediaDecoderProtocl <NSObject>
@optional
-(void)initOpenglView;
-(void)initAudioPlayer:(AudioStreamBasicDescription )audioFormat;
-(void)showFirsKeyYuvFrame:(LLVideoFrameYUV *)yuvFrame;
-(void)addNewFrames;
@end
//父类
@interface LLMediaFrame : NSObject
//音频还是视频
@property (readonly, nonatomic) LLMediaFrameType type;
//显示时间戳
@property (readonly, nonatomic) CGFloat timestamp;
//持续时间
@property(readonly, nonatomic, assign)CGFloat duration;
@end

@interface LLVideoFrame:LLMediaFrame
//视频帧格式
@property (readonly, nonatomic) LLVideoFrameFormat format;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;
@end

@interface LLVideoFrameYUV:LLVideoFrame
//y数据
@property (readonly, nonatomic, strong) NSData *luma;
//u数据
@property (readonly, nonatomic, strong) NSData *chromaB;
//v数据
@property (readonly, nonatomic, strong) NSData *chromaR;
@end

@interface LLAudioFrame:LLMediaFrame
//pcm数据
@property (readonly, nonatomic, strong) NSData *samples;
@end

@interface LLMediaDecoder : NSObject
-(BOOL)isValidtyVideo;
-(BOOL)isValidtyAudio;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;


@property(nonatomic,strong)NSDate *startDate;
@property(nonatomic,weak)id<MediaDecoderProtocl> delegete;
//存放解码后的每一帧数据
@property(nonatomic,strong)NSMutableArray <LLMediaFrame *>*frames;
//打开文件开始播放
-(void)openFile:(NSString *)path;
//开始解码
-(void)startDecodeDuration:(CGFloat)duration;

@end
