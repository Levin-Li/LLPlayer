//
//  LLDecoder.m
//  LLPlayer
//
//  Created by mac on 2016/12/21.
//  Copyright © 2016年 luolei. All rights reserved.
//

#import "LLDecoder.h"

@interface KxMovieFrame()
@property (readwrite, nonatomic) CGFloat position;
@property (readwrite, nonatomic) CGFloat duration;
@end

@implementation KxMovieFrame
@end

@interface KxVideoFrame()
//@property (readwrite, nonatomic) NSUInteger width;
//@property (readwrite, nonatomic) NSUInteger height;
@end

@implementation KxVideoFrame
- (KxMovieFrameType) type { return KxMovieFrameTypeVideo; }
@end

@interface KxVideoFrameYUV()
//@property (readwrite, nonatomic, strong) NSData *luma;
//@property (readwrite, nonatomic, strong) NSData *chromaB;
//@property (readwrite, nonatomic, strong) NSData *chromaR;
@end

@implementation KxVideoFrameYUV
- (KxVideoFrameFormat) format { return KxVideoFrameFormatYUV; }
@end

@implementation LLDecoder

@end
