//
//  LLMediaDecoder.m
//  LLPlayer
//
//  Created by luo luo on 19/10/2017.
//  Copyright © 2017 luolei. All rights reserved.
//

#import "LLMediaDecoder.h"
#include <libavformat/avformat.h>
#include <libavutil/mathematics.h>
#include <libavutil/time.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
#import <objc/objc.h>

# define LLLog(format, ...) NSLog((@"className:%@" "[line:%d]" format),NSStringFromClass([self class]),__LINE__, ##__VA_ARGS__);

@interface LLMediaFrame()
@property (nonatomic, assign) LLMediaFrameType type;
@property (assign, nonatomic) CGFloat timestamp;
@property (nonatomic, assign)CGFloat duration;
@end
@implementation LLMediaFrame

@end

@interface LLVideoFrame()
@property (readwrite, nonatomic) NSUInteger width;
@property (readwrite, nonatomic) NSUInteger height;
@end
@implementation LLVideoFrame
@end

@interface LLVideoFrameYUV()
//y数据
@property (readwrite, nonatomic, strong) NSData *luma;
//u数据
@property (readwrite, nonatomic, strong) NSData *chromaB;
//v数据
@property (readwrite, nonatomic, strong) NSData *chromaR;
@end
@implementation LLVideoFrameYUV
@end

@interface LLMediaDecoder()
@property(nonatomic,copy)NSString  *filePath;
@property(nonatomic,assign)double videoTimebase;
@end

@implementation LLMediaDecoder{
    AVFormatContext *pformatCtx;
    //视频
    int videoIndex;
    AVCodecContext *videoCodecCtx;
    AVCodec *videoCodec;
    AVFrame *videoFrame,*videoFrameYUV;
    uint8_t *out_buffer;
    AVPacket *videoPacket;
    int y_size;
    int ret,got_picture;
    
    struct SwsContext *img_convert_ctx;
}
-(NSMutableArray <LLVideoFrameYUV *>*)yuvframes
{
    if (!_yuvframes) {
        _yuvframes = [[NSMutableArray alloc]init];
    }
    return  _yuvframes;
}

-(BOOL)isValidtyVideo
{
    return videoIndex == -1?NO:YES;
}

-(void)openFile:(NSString *)path
{
    NSAssert(path, @"path is nill !!!");
    self.filePath = path;
    av_register_all();
    avformat_network_init();
    pformatCtx = avformat_alloc_context();
    // open format file to formatCtx
    if (avformat_open_input(&pformatCtx,[path UTF8String],NULL,NULL) != 0) {
        printf("couldn't open input stream.\n");
        return;
    }
    
    
    if (avformat_find_stream_info(pformatCtx,NULL) < 0) {
        printf("couldn't find stream information.\n");
        return;
    }
    
    videoIndex = -1;
    for (int i= 0; i<pformatCtx->nb_streams; i++) {
        if (pformatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoIndex = i;
            printf("find video stream %d\n",i);
            //            break;
        }
        
    }
    
    if (videoIndex == -1) {
        printf("Didn't find avideo stream ");
        return;
    }
    //打印流中的timeBase
    AVStream *videoStream = pformatCtx->streams[videoIndex];
    //fps= 1/timebase
    LLLog(@"Video stream timeBase:%f avg_fps:%f fps:%f",av_q2d(videoStream->time_base),av_q2d(videoStream->avg_frame_rate),av_q2d(videoStream->r_frame_rate));
    
    if (videoStream->time_base.den && videoStream->time_base.num)
        _videoTimebase = av_q2d(videoStream->time_base);//此处的会慢一些
    else if(videoStream->codec->time_base.den && videoStream->codec->time_base.num)
        _videoTimebase = av_q2d(videoStream->codec->time_base);
    else
        _videoTimebase = 0.04;//获取不到时设为0.04
    //打开视频流
    [self openVideoStream];
}

-(void)openVideoStream
{
    videoCodecCtx=pformatCtx->streams[videoIndex]->codec;
    videoCodec=avcodec_find_decoder(videoCodecCtx->codec_id);

    LLLog(@"Video codecCtx timeBase:%f Usetimebase:%f ",av_q2d(videoCodecCtx->time_base),self.videoTimebase);
    if(videoCodec==NULL)
    {
        printf("video Codec not found.\n");
        return;
    }
    
    if(avcodec_open2(videoCodecCtx, videoCodec,NULL)<0)
    {
        printf("Could not open codec.\n");
        return;
    }else{
        printf("open codec.\n");
    }
    //打印获取的全部信息
    av_dump_format(pformatCtx, 0, [self.filePath UTF8String], 0);
    
    //解码出每一帧
    //init Frame
    videoFrame = av_frame_alloc();
    videoFrameYUV = av_frame_alloc();
    //分配输出内存空间
    out_buffer = (uint8_t *)av_malloc(avpicture_get_size(PIX_FMT_YUV420P, videoCodecCtx->width, videoCodecCtx->height));
    avpicture_fill((AVPicture *)videoFrameYUV, out_buffer, PIX_FMT_YUV420P, videoCodecCtx->width, videoCodecCtx->height);
    videoPacket = (AVPacket *)av_malloc(sizeof(AVPacket));
    LLLog(@"origin video format:%d",videoCodecCtx->pix_fmt);
    //转格式为PIX_FMT_YUV420P
    img_convert_ctx = sws_getContext(videoCodecCtx->width, videoCodecCtx->height, videoCodecCtx->pix_fmt,
                                     videoCodecCtx->width, videoCodecCtx->height, PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);//转码的信息
    //每次读一个包出来直到所有包读完
    while (av_read_frame(pformatCtx, videoPacket)>=0) {
        ret = 0;got_picture= 0;
        
//        NSLog(@"paktPts:%lld",videoPacket->pts);
        if (videoPacket->stream_index==videoIndex) {
            //解码一帧数据出来 ret代表从packt解码的数据长度
            ret = avcodec_decode_video2(videoCodecCtx, videoFrame, &got_picture, videoPacket);
            if (ret<0) {
                printf("Decode Error.\n");
                return ;
            }
            NSLog(@"decode packet lenght:%d",ret);
            if (got_picture == 0) {
                printf("no get picture !\n");
            }
            if (got_picture) {
                //转成一帧yuv数据 此处的yuv帧只存yuv数据其它数据都不存
                sws_scale(img_convert_ctx, (const uint8_t* const*)videoFrame->data, videoFrame->linesize, 0, videoCodecCtx->height, videoFrameYUV->data, videoFrameYUV->linesize);
                //视频帧的显示时间pts
                double timestamp = av_frame_get_best_effort_timestamp(videoFrame)*self.videoTimebase;
                NSLog(@"video time stamp:%lf",timestamp);
                //必要信息存储起来
                LLVideoFrameYUV *yuvFrame = [[LLVideoFrameYUV alloc]init];
                yuvFrame.type = LLMediaFrameTypeVideo;
                yuvFrame.timestamp = timestamp;
                yuvFrame.width = videoCodecCtx->width;
                yuvFrame.height = videoCodecCtx->height;
                yuvFrame.luma = copyFrameData(videoFrameYUV->data[0],
                                              videoFrameYUV->linesize[0],
                                              videoCodecCtx->width,
                                              videoCodecCtx->height);
                
                yuvFrame.chromaB = copyFrameData(videoFrameYUV->data[1],
                                                 videoFrameYUV->linesize[1],
                                                 videoCodecCtx->width / 2,
                                                 videoCodecCtx->height / 2);
                
                yuvFrame.chromaR = copyFrameData(videoFrameYUV->data[2],
                                                 videoFrameYUV->linesize[2],
                                                 videoCodecCtx->width / 2,
                                                 videoCodecCtx->height / 2);
                const int64_t frameDuration = av_frame_get_pkt_duration(videoFrame);
                if (frameDuration) {
                    yuvFrame.duration = frameDuration * self.videoTimebase;
                    // 当前帧的显示时间戳 * 时基 +额外的延迟时间 extra_delay = repeat_pict / (2*fps)
                    //科普：fps = 1.0/timebase
                    yuvFrame.duration += videoFrame->repeat_pict * self.videoTimebase * 0.5;
                }
//                NSLog(@"yuvframeDuration:%f",yuvFrame.duration);
                [self.yuvframes addObject:yuvFrame];
                
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    LLLog(@"get first frame start show .");
                    self.startDate = [NSDate date];
                });
                if (self.delegete && [self.delegete respondsToSelector:@selector(showYuvFrame:)]) {
                    [self.delegete showYuvFrame:self];
                }
            }
        }
        

    }
//    [self closeDecoder];
}

-(void)closeDecoder
{
            av_free_packet(videoPacket);
            sws_freeContext(img_convert_ctx);
            av_frame_free(&videoFrameYUV);
            av_frame_free(&videoFrame);
            avcodec_close(videoCodecCtx);
            avformat_close_input(&pformatCtx);
}

#pragma mark 其它
static NSData * copyFrameData(UInt8 *src, int linesize, int width, int height)
{
    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength: width * height];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    
    return md;
}

@end
