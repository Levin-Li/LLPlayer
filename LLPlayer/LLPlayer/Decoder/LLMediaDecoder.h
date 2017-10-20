//
//  LLMediaDecoder.h
//  LLPlayer
//
//  Created by luo luo on 19/10/2017.
//  Copyright © 2017 luolei. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>


typedef enum {
    LLMediaFrameTypeAudio,
    LLMediaFrameTypeVideo,
} LLMediaFrameType;

typedef enum {
    LLVideoFrameFormatYUV,
}LLVideoFrameFormat;

@class LLMediaDecoder;
@protocol MediaDecoderProtocl <NSObject>
@optional
-(void)showYuvFrame:(LLMediaDecoder*)decoer;
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

@interface LLMediaDecoder : NSObject
@property(nonatomic,strong)NSDate *startDate;
@property(nonatomic,weak)id<MediaDecoderProtocl> delegete;
//存放解码后的每一帧数据
@property(nonatomic,strong)NSMutableArray <LLVideoFrameYUV *>*yuvframes;
//打开文件开始播放
-(void)openFile:(NSString *)path;

@end
