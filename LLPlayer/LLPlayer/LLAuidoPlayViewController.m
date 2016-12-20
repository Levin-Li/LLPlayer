//
//  LLAuidoPlayViewController.m
//  LLPlayer
//
//  Created by mac on 2016/12/16.
//  Copyright © 2016年 luolei. All rights reserved.
//

#import "LLAuidoPlayViewController.h"
#include <libavformat/avformat.h>
#include <libavutil/mathematics.h>
#include <libavutil/time.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
#import "LLAudioOutPutQueue.h"

//Output PCM
#define OUTPUT_PCM 1
//音频
#define MAX_AUDIO_FRAME_SIZE 192000 // 1 second of 48khz 32bit audio

@interface LLAuidoPlayViewController ()

@end

@implementation LLAuidoPlayViewController{
    AVFormatContext *pformatCtx;
    //视频
    AVCodecContext *pCodecCtx;
    //音频
    int audioIndex;
    AVCodecContext *audioCodecCtx;
    AVCodec *audioCodec;
    AVPacket *audioPacket;
    uint8_t *audioOut_buffer;//最后输出的pcm数据
    AVFrame *audioFrame;
    int64_t in_channel_layout;
    int audioRet,audioGot_picture;
    
    struct SwrContext *au_convert_ctx;
    int audioTag;//每帧音频标记(用于打印)
    //
    LLAudioOutPutQueue *_audioPcm;
     FILE *pFile;
    int ret;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    pFile = NULL;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSLog(@"音频播放界面");
    
}

- (IBAction)startPlay:(id)sender {
    [self getAudioData];
}


-(void)getAudioData
{
    NSString *input_str= [NSString stringWithFormat:@"resource.bundle/%@",@"war3end.mp4"];//war3end.mp4  sintel.h264 WavinFlag.aac
    NSString *input_nsstr=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:input_str];
    //    input_nsstr = @"rtmp://rtslive200.dnion.com/rts200/78346698-877c-40b3-95e8-d35519874f61";
    //init ffmpeg
    av_register_all();
    avformat_network_init();
    pformatCtx = avformat_alloc_context();
    // open format file to formatCtx
    if (avformat_open_input(&pformatCtx,[input_nsstr UTF8String],NULL,NULL) != 0) {
        printf("couldn't open input stream.\n");
        return;
    }
    //    av_dump_format(pformatCtx, 0, [input_nsstr UTF8String], 0);
    
    if (avformat_find_stream_info(pformatCtx,NULL) < 0) {
        printf("couldn't find stream information.\n");
        return;
    }
    audioIndex = -1;
    for (int i= 0; i<pformatCtx->nb_streams; i++) {
        if(pformatCtx->streams[i]->codec->codec_type==AVMEDIA_TYPE_AUDIO){
            audioIndex=i;
            printf("find audio stream %d\n",i);
                        break;
        }
    }
    
    if (audioIndex == -1) {
        printf("Didn't find audio stream");
    }
    
    //音频
    audioCodecCtx = pformatCtx->streams[audioIndex]->codec;
    audioCodec = avcodec_find_decoder(audioCodecCtx->codec_id);
    
    if(audioCodec==NULL){
        printf("Codec not found.\n");
        return;
    }
    if (audioCodecCtx==NULL) {
        printf("audioCodec not found.\n");
        return;
    }
    // Open codec
    if(avcodec_open2(audioCodecCtx, audioCodec,NULL)<0){
        printf("Could not open audioCodec.\n");
        return ;
    }
    
    //Output Info-----------------------------
    printf("--------------- File Information ----------------\n");
    av_dump_format(pformatCtx, 0, [input_nsstr UTF8String], 0);
    printf("-------------------------------------------------\n");
   
    //***开始音频播放
    [self audioPcmPlay];
   
}

-(void)audioPcmPlay
{
#if OUTPUT_PCM
    pFile=fopen("/Users/mac/Desktop/pcmData.pcm", "wb");
#endif
    _audioPcm = [[LLAudioOutPutQueue alloc]init];
    audioPacket=(AVPacket *)av_malloc(sizeof(AVPacket));
    av_init_packet(audioPacket);
    
    //Out Audio Param
    uint64_t out_channel_layout=AV_CH_LAYOUT_STEREO;
    //nb_samples: AAC-1024 MP3-1152
    int out_nb_samples=audioCodecCtx->frame_size;
    enum AVSampleFormat out_sample_fmt=AV_SAMPLE_FMT_S16;
    int out_sample_rate=44100;
    int out_channels=av_get_channel_layout_nb_channels(out_channel_layout);
    //Out Buffer Size
    int out_buffer_size=av_samples_get_buffer_size(NULL,out_channels ,out_nb_samples,out_sample_fmt, 1);
    
    audioOut_buffer=(uint8_t *)av_malloc(MAX_AUDIO_FRAME_SIZE*2);
    audioFrame=av_frame_alloc();
    
    
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = 44100;
    audioFormat.mChannelsPerFrame = 2;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mBytesPerPacket = audioFormat.mBytesPerFrame = (audioFormat.mBitsPerChannel / 8) * audioFormat.mChannelsPerFrame;
    audioFormat.mFramesPerPacket = 1;
    
    int ByteN = audioFormat.mBytesPerFrame = (audioFormat.mBitsPerChannel / 8) * audioFormat.mChannelsPerFrame;
    NSLog(@"out_sample_rate=%d out_channels=%d out_buffer_size=%d ByteN=%d",out_sample_rate,out_channels,out_buffer_size,ByteN);
    NSLog(@"channels=%d nb_samples=%d sample_fmt=%d sample_rate=%d",audioCodecCtx->channels,audioFrame->nb_samples,audioCodecCtx->sample_fmt,audioCodecCtx->sample_rate);
    [_audioPcm registAudio:audioFormat];
    // FIX:Some Codec's Context Information is missing
    in_channel_layout=av_get_default_channel_layout(audioCodecCtx->channels);
    
    //Swr
    au_convert_ctx = swr_alloc();
    au_convert_ctx=swr_alloc_set_opts(au_convert_ctx,out_channel_layout, out_sample_fmt, out_sample_rate,
                                      in_channel_layout,audioCodecCtx->sample_fmt , audioCodecCtx->sample_rate,0, NULL);
    swr_init(au_convert_ctx);
    
    audioTag = 0;
    audioGot_picture = 0;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (av_read_frame(pformatCtx, audioPacket) >=0) {
            if (audioPacket->stream_index == audioIndex) {
                audioRet = avcodec_decode_audio4(audioCodecCtx, audioFrame, &audioGot_picture, audioPacket);
                if (ret < 0) {
                    printf("Error in decoding audio frame.\n");
                    return;
                }
                if (audioGot_picture > 0) {
                    swr_convert(au_convert_ctx, &audioOut_buffer, MAX_AUDIO_FRAME_SIZE, (const uint8_t **)audioFrame->data, audioFrame->nb_samples);
                    
#if OUTPUT_PCM
                    //Write PCM
                    fwrite(audioOut_buffer, 1, out_buffer_size, pFile);
                    //NSLog(@"input file count=%zu",writeCount);
#endif
                    
                    printf("index:%5d\t pts:%lld\t packet size:%d\n",audioTag,audioPacket->pts,audioPacket->size);
                    NSData *pcmdata = [NSData dataWithBytes:audioOut_buffer length:out_buffer_size];
                    [_audioPcm.receiveData addObject:pcmdata];
                    audioTag ++;
                    
                }else{
                    NSLog(@"not get audio!!!");
                }
            }
        }
        av_free_packet(audioPacket);
        swr_free(&au_convert_ctx);
#if OUTPUT_PCM
        fclose(pFile);
#endif
    });
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
