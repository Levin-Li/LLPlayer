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


//音频
#define MAX_AUDIO_FRAME_SIZE 192000 // 1 second of 48khz 32bit audio

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

@interface LLAudioFrame()
@property (readwrite, nonatomic, strong) NSData *samples;
@end
@implementation LLAudioFrame
@end

@interface LLMediaDecoder()
@property (readwrite, nonatomic) NSUInteger width;
@property (readwrite, nonatomic) NSUInteger height;
@property(nonatomic,copy)NSString  *filePath;
@property(nonatomic,assign)double videoTimebase;
@property(nonatomic,assign)double audioTimebase;
@end

@implementation LLMediaDecoder{
    AVFormatContext *pformatCtx;
    //视频
    int videoIndex;
    AVCodecContext *videoCodecCtx;
    AVCodec *videoCodec;
    AVFrame *videoFrame,*videoFrameYUV;
    uint8_t *out_buffer;
    AVPacket *packet;
    
    struct SwsContext *img_convert_ctx;
    
    //音频
    int audioIndex;
    AVCodecContext *audioCodecCtx;
    AVCodec *audioCodec;
    AVFrame *audioFrame;
    //解码并转换后的pcm数据
    uint8_t *audioOut_buffer;
    struct SwrContext *audio_convert_ctx;
    int audio_out_buffer_size;
}
-(NSMutableArray <LLMediaFrame *>*)frames
{
    if (!_frames) {
        _frames = [[NSMutableArray alloc]init];
    }
    return  _frames;
}

-(BOOL)isValidtyVideo
{
    return videoIndex == -1?NO:YES;
}
-(BOOL)isValidtyAudio
{
    return audioIndex == -1?NO:YES;
}
#pragma mark 初始化
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
    audioIndex = -1;
    for (int i= 0; i<pformatCtx->nb_streams; i++) {
        if (pformatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoIndex = i;
            printf("find video stream %d\n",i);
        }
        if(pformatCtx->streams[i]->codec->codec_type==AVMEDIA_TYPE_AUDIO){
            audioIndex=i;
            printf("find audio stream %d\n",i);
        }
    }
    
    if (videoIndex == -1) {
        printf("Didn't find avideo stream !!!");
        return;
    }
    if (![self isValidtyAudio]) {
        printf("Didn't find audio stream !!!");
    }
    
    //初始化音频解码
     [self initAudioDecode];
    //初始化视频解码
    [self initVideoDecode];
    //开始解码
    [self startDecode];
    
}
#pragma mark 视频处理
-(void)initVideoDecode
{
    //打印流中的timeBase
    AVStream *videoStream = pformatCtx->streams[videoIndex];
    
    if (videoStream->time_base.den && videoStream->time_base.num)
        _videoTimebase = av_q2d(videoStream->time_base);//封装层的timebase
    else if(videoStream->codec->time_base.den && videoStream->codec->time_base.num)
        _videoTimebase = av_q2d(videoStream->codec->time_base);//编码层的timebase =1/fps
    else
        _videoTimebase = 0.04;//获取不到时设为0.04
    
    videoCodecCtx=pformatCtx->streams[videoIndex]->codec;
    videoCodec=avcodec_find_decoder(videoCodecCtx->codec_id);
    self.width = videoCodecCtx->width;
    self.height = videoCodecCtx->height;
    if (self.delegete && [self.delegete respondsToSelector:@selector(initOpenglView)]) {
        [self.delegete initOpenglView];
    }
    
    LLLog(@"Video stream timeBase:%f codecCtx timebase:%f userTimebase:%f avg_fps:%f fps:%f",av_q2d(videoStream->time_base),av_q2d(videoCodecCtx->time_base),self.videoTimebase,av_q2d(videoStream->avg_frame_rate),av_q2d(videoStream->r_frame_rate));
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
    LLLog(@"origin video format:%d",videoCodecCtx->pix_fmt);
    //转格式为PIX_FMT_YUV420P
    img_convert_ctx = sws_getContext(videoCodecCtx->width, videoCodecCtx->height, videoCodecCtx->pix_fmt,
                                     videoCodecCtx->width, videoCodecCtx->height, PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);//转码的信息
}

-(void)startDecode
{
    //移除所有的帧
    [self.frames removeAllObjects];
    
    packet = (AVPacket *)av_malloc(sizeof(AVPacket));
    int ret,got_picture;
    BOOL isfinish = NO;
    //每次读一个包出来直到所有包读完
    while (!isfinish) {
        if (av_read_frame(pformatCtx, packet)>=0) {
            ret = 0;got_picture= 0;
            NSLog(@"paktPts:%lld",packet->pts);
            if (packet->stream_index==videoIndex) {
                //解码一帧数据出来 ret代表从packt解码的数据长度
                ret = avcodec_decode_video2(videoCodecCtx, videoFrame, &got_picture, packet);
                if (ret<0) {
                    printf("Decode Error.\n");
                    return ;
                }
                LLLog(@"videoPacketLenght:%d",ret);
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
                    [self.frames addObject:yuvFrame];
                    if (videoFrame->key_frame) {
                        NSLog(@"it is key frame!");
                        static dispatch_once_t onceToken;
                        dispatch_once(&onceToken, ^{
                            if ( self.delegete && [self.delegete respondsToSelector:@selector(showFirsKeyYuvFrame:)]) {
                                [self.delegete showFirsKeyYuvFrame:yuvFrame];
                            }
                        });
                    }
                    
                    
                    if (self.frames.count>50) {
                        isfinish = YES;//退出
                    }
                    
                }
            }else if (packet->stream_index == audioIndex){
                //音频处理
                ret = avcodec_decode_audio4(audioCodecCtx, audioFrame, &got_picture, packet);
                if (ret < 0) {
                    LLLog("Error in decoding audio frame. !!!");
                    return;
                }
                if (got_picture) {
                    swr_convert(audio_convert_ctx, &audioOut_buffer, MAX_AUDIO_FRAME_SIZE, (const uint8_t **)audioFrame->data, audioFrame->nb_samples);
                    LLLog("AudioPacketLenght:%5d\t pts:%lld\t packet size:%d\n",ret,packet->pts,packet->size);
                    LLAudioFrame *frame = [[LLAudioFrame alloc]init];
                    frame.type = LLMediaFrameTypeAudio;
                    frame.samples = [NSData dataWithBytes:audioOut_buffer length:audio_out_buffer_size];
                    frame.timestamp = av_frame_get_best_effort_timestamp(audioFrame) * self.audioTimebase;
                    frame.duration = av_frame_get_pkt_duration(audioFrame) * self.audioTimebase;
                    [self.frames addObject:frame];
                    
                }
            }
        }
    }
    
    if (self.delegete && [self.delegete respondsToSelector:@selector(addNewFrames)]) {
        [self.delegete addNewFrames];
    }
    
    av_free_packet(packet);
   
    // [self closeVideoDecoder];
    
}

-(void)closeVideoDecoder
{
            sws_freeContext(img_convert_ctx);
            av_frame_free(&videoFrameYUV);
            av_frame_free(&videoFrame);
            avcodec_close(videoCodecCtx);
            avformat_close_input(&pformatCtx);
}

#pragma mark 音频处理

-(void)initAudioDecode
{
    //音频
    AVStream *audioStream = pformatCtx->streams[audioIndex];
    //fps= 1/timebase
    
    
    if (audioStream->time_base.den && audioStream->time_base.num)
        _audioTimebase = av_q2d(audioStream->time_base);//封装层的timebase
    else if(audioStream->codec->time_base.den && audioStream->codec->time_base.num)
        _audioTimebase = av_q2d(audioStream->codec->time_base);//编码层的timebase =1/fps
    else
        _audioTimebase = 0.025;//获取不到时设为0.025
    
    LLLog(@"Video stream timeBase:%f userTimebase:%f avg_fps:%f fps:%f",av_q2d(audioStream->time_base),self.audioTimebase,av_q2d(audioStream->avg_frame_rate),av_q2d(audioStream->r_frame_rate));
    
    audioCodecCtx = pformatCtx->streams[audioIndex]->codec;
    audioCodec = avcodec_find_decoder(audioCodecCtx->codec_id);
    if (audioCodec == NULL) {
        LLLog(@"Do Not find audio decoder !!!");
    }
    
    if(avcodec_open2(audioCodecCtx, audioCodec,NULL)<0){
        printf("Could not open audioCodec.\n");
        return ;
    }
    
    LLLog(@"channels=%d sample_fmt=%d",audioCodecCtx->channels,audioCodecCtx->sample_fmt);
    audioFrame=av_frame_alloc();
    
    //解码后的pcm需要转成的播放格式
    uint64_t out_channel_layout=AV_CH_LAYOUT_STEREO;
    //nb_samples: AAC-1024 MP3-1152
    int out_nb_samples=audioCodecCtx->frame_size;
    enum AVSampleFormat out_sample_fmt=AV_SAMPLE_FMT_S16;
    int out_sample_rate=44100;
    int out_channels=av_get_channel_layout_nb_channels(out_channel_layout);
    //Out Buffer Size
     audio_out_buffer_size = av_samples_get_buffer_size(NULL,out_channels ,out_nb_samples,out_sample_fmt, 1);
    
    audioOut_buffer=(uint8_t *)av_malloc(MAX_AUDIO_FRAME_SIZE*2);
    
    //播放格式
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = out_sample_rate;
    audioFormat.mChannelsPerFrame = out_channels;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    audioFormat.mBitsPerChannel = 16;
    int ByteN = audioFormat.mBytesPerFrame = (audioFormat.mBitsPerChannel / 8) * audioFormat.mChannelsPerFrame;
    audioFormat.mBytesPerPacket = audioFormat.mBytesPerFrame = (audioFormat.mBitsPerChannel / 8) * audioFormat.mChannelsPerFrame;
    audioFormat.mFramesPerPacket = 1;
    LLLog(@"out_sample_rate=%d out_channels=%d out_buffer_size=%d ByteN=%d",out_sample_rate,out_channels,audio_out_buffer_size,ByteN);
    //初始化音频播放器
    if (self.delegete && [self.delegete respondsToSelector:@selector(initAudioPlayer:)]) {
        [self.delegete initAudioPlayer:audioFormat];
    }
    
    //转换
    audio_convert_ctx = swr_alloc();
   int64_t in_channel_layout=av_get_default_channel_layout(audioCodecCtx->channels);
    audio_convert_ctx=swr_alloc_set_opts(audio_convert_ctx,out_channel_layout, out_sample_fmt, out_sample_rate,
                                      in_channel_layout,audioCodecCtx->sample_fmt , audioCodecCtx->sample_rate,0, NULL);
    swr_init(audio_convert_ctx);
    
    
 
    
    
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

-(void)dealloc
{
    NSLog(@"dealloc %@",NSStringFromClass([self class]));
    [self closeVideoDecoder];
    
}
@end
