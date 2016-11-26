//
//  ViewController.m
//  LLPlayer
//
//  Created by luoluo on 16/10/19.
//  Copyright © 2016年 luolei. All rights reserved.
//

#import "ViewController.h"
#include <libavformat/avformat.h>
#include <libavutil/mathematics.h>
#include <libavutil/time.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
#include "SDL.h"
#include <stdio.h>
#include <time.h>
#import "OpenglView.h"
#import "LLSDLPlayViewController.h"
//#import <SystemConfiguration/SystemConfiguration.h>

//Output YUV420P data as a file
#define OUTPUT_YUV420P 0
//音频
#define MAX_AUDIO_FRAME_SIZE 192000 // 1 second of 48khz 32bit audio
@interface ViewController ()

@end

//Refresh Event
#define SFM_REFRESH_EVENT  (SDL_USEREVENT + 1)

#define SFM_BREAK_EVENT  (SDL_USEREVENT + 2)

//音频
#define SFM_AudioRefresh_event (SDL_USEREVENT + 3)
#define SFM_AudioBreak_event (SDL_USEREVENT + 4)
int thread_exit1 =0;
int audio_thread_exit1 = 0;
//视频线程
int sfp_refresh_thread(void *opaque){
    thread_exit1=0;
    while (!thread_exit1) {
        SDL_Event event;
        event.type = SFM_REFRESH_EVENT;
        SDL_PushEvent(&event);
        SDL_Delay(40);
    }
    thread_exit1=0;
    //Break
    SDL_Event event;
    event.type = SFM_BREAK_EVENT;
    SDL_PushEvent(&event);
    
    return 0;
}
//音频线程
int sfp_refresh_audio_thread(void *opaque){
    audio_thread_exit1=0;
    while (!audio_thread_exit1) {
        SDL_Event event;
        event.type = SFM_AudioRefresh_event;
        SDL_PushEvent(&event);
        SDL_Delay(1);
    }
    audio_thread_exit1=0;
    //Break
    SDL_Event event;
    event.type = SFM_AudioBreak_event;
    SDL_PushEvent(&event);
    
    return 0;
}


//void
//fatalError(const char *string)
//{
//    printf("%s: %s\n", string, SDL_GetError());
////    exit(1);
//}
//int
//randomInt(int min, int max)
//{
//    return min + rand() % (max - min + 1);
//}
@implementation ViewController{
    AVFormatContext *pformatCtx;
    //视频
    int videoIndex;
    AVCodecContext *pCodecCtx;
    AVCodec *pCodec;
    AVFrame *pFrame,*pFrameYUV;
    uint8_t *out_buffer;
    AVPacket *packet;
    int y_size;
    int ret,got_picture;
    struct SwsContext *img_convert_ctx;
    //音频
    int audioIndex;
    AVCodecContext *audioCodecCtx;
    AVCodec *audioCodec;
    AVPacket *audioPacket;
    uint8_t *audioOut_buffer;//最后输出的pcm数据
    AVFrame *audioFrame;
    int64_t in_channel_layout;
    int audioRet,audioGot_picture;
    int audioTag;//每帧音频标记(用于打印)
    //SDL
    //SDL---------------------------
    int screen_w,screen_h;
    SDL_Window *screen;
    SDL_Renderer* sdlRenderer;
    SDL_Texture* sdlTexture;
    SDL_Rect sdlRect;
    //音频
    SDL_AudioSpec wanted_spec;
    struct SwrContext *au_convert_ctx;
    
    //GLView
//    OpenglView *_glView;
//    int thread_exit;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.view.backgroundColor = [UIColor redColor];
//    [self createGLView];

   
    //SDL显示一个矩形
//    [self createRectangle];
   }

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
     [self getFrameYUV];
}

-(void)getFrameYUV
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
    
    
    
    videoIndex = -1;
    for (int i= 0; i<pformatCtx->nb_streams; i++) {
        if (pformatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoIndex = i;
            printf("find video stream\n");
            break;
        }
        if(pformatCtx->streams[i]->codec->codec_type==AVMEDIA_TYPE_AUDIO){
            audioIndex=i;
            printf("find audio stream\n");
            break;
        }
    }
    
    if (videoIndex == -1) {
        printf("Didn't find avideo stream");
    }
    
    pCodecCtx=pformatCtx->streams[videoIndex]->codec;
    pCodec=avcodec_find_decoder(pCodecCtx->codec_id);
    //音频
    audioCodecCtx = pformatCtx->streams[audioIndex]->codec;
    audioCodec = avcodec_find_decoder(audioCodecCtx->codec_id);
    
    
    if(pCodec==NULL)
    {
        printf("Codec not found.\n");
        return;
    }
    
    if(avcodec_open2(pCodecCtx, pCodec,NULL)<0)
    {
        printf("Could not open codec.\n");
        return;
    }else{
        printf("open codec.\n");
    }
    if(audioCodec==NULL){
        printf("Codec not found.\n");
        return;
    }
    // Open codec
    if(avcodec_open2(audioCodecCtx, audioCodec,NULL)<0){
        printf("Could not open audioCodec.\n");
        return ;
    }
    
    
    //init Frame
    pFrame = av_frame_alloc();
    pFrameYUV = av_frame_alloc();
        //分配输出内存空间
    out_buffer = (uint8_t *)av_malloc(avpicture_get_size(PIX_FMT_YUV420P, pCodecCtx->width, pCodecCtx->height));
    avpicture_fill((AVPicture *)pFrameYUV, out_buffer, PIX_FMT_YUV420P, pCodecCtx->width, pCodecCtx->height);//分配内存空间
//    out_buffer=(unsigned char *)av_malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P,  pCodecCtx->width, pCodecCtx->height,1));
//    av_image_fill_arrays(pFrameYUV->data, pFrameYUV->linesize,out_buffer,
//                         AV_PIX_FMT_YUV420P,pCodecCtx->width, pCodecCtx->height,1);
    packet = (AVPacket *)av_malloc(sizeof(AVPacket));//
    //Output Info-----------------------------
    printf("--------------- File Information ----------------\n");
    av_dump_format(pformatCtx, 0, [input_nsstr UTF8String], 0);
    printf("-------------------------------------------------\n");
    //转格式为PIX_FMT_YUV420P
    img_convert_ctx = sws_getContext(pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt,
                                     pCodecCtx->width, pCodecCtx->height, PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);//转码的信息
#if OUTPUT_YUV420P
   FILE *fp_yuv=fopen("/Users/mac/Desktop/Respose/output.yuv","wb+");
#endif
    
    //SDL----------------------------
    SDL_SetMainReady();//使用官网的需要先执行这句 不然初始化不成功
    if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER)< 0) {
        printf( "Could not initialize SDL - %s\n", SDL_GetError());
        return ;
    }
    
    screen_w = pCodecCtx->width;
    screen_h = pCodecCtx->height;
    // create window and renderer
    
    screen = SDL_CreateWindow("Simplest ffmpeg player's Window", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              screen_w, screen_h,
                              SDL_WINDOW_OPENGL);
    
    if(!screen) {
        printf("SDL: could not create window - exiting:%s\n",SDL_GetError());
        return;
    }
    
    sdlRenderer = SDL_CreateRenderer(screen, -1, 0);
    //IYUV: Y + U + V  (3 planes)
    //YV12: Y + V + U  (3 planes)
    sdlTexture = SDL_CreateTexture(sdlRenderer, SDL_PIXELFORMAT_IYUV, SDL_TEXTUREACCESS_STREAMING,pCodecCtx->width,pCodecCtx->height);
    
    sdlRect.x=0;
    sdlRect.y=0;
    sdlRect.w=screen_w;
    sdlRect.h=screen_h;
    printf("screenw:%d screenh:%d\n",screen_w,screen_h);
    
    //SDL End----------------------
    
    //***开始音频播放
    [self audioPlay];
    
    //***开始视频播放
    [self videoPlay];
   
    
    
}

-(void)videoPlay
{
    SDL_Thread *video_tid = SDL_CreateThread(sfp_refresh_thread,NULL,NULL);
    SDL_Event event;
    for (;;) {
        //Wait
        SDL_WaitEvent(&event);
        if (event.type == SFM_REFRESH_EVENT) {
            //---------------------------------
            if(av_read_frame(pformatCtx, packet)>=0){
                if(packet->stream_index==videoIndex){
                    ret = avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, packet);
                    if(ret < 0){
                        printf("Decode Error.\n");
                        return ;
                    }
                    if(got_picture){
                        sws_scale(img_convert_ctx, (const uint8_t* const*)pFrame->data, pFrame->linesize, 0, pCodecCtx->height, pFrameYUV->data, pFrameYUV->linesize);
                        //SDL---------------------------
                        SDL_UpdateTexture( sdlTexture, NULL, pFrameYUV->data[0], pFrameYUV->linesize[0]);
                        //添加到纹理(此方法也可以)
                        //                        SDL_UpdateYUVTexture(sdlTexture, &sdlRect,
                        //                                             pFrameYUV->data[0], pFrameYUV->linesize[0],
                        //                                             pFrameYUV->data[1], pFrameYUV->linesize[1],
                        //                                             pFrameYUV->data[2], pFrameYUV->linesize[2]);
                        
                        SDL_RenderClear( sdlRenderer );
                        SDL_RenderCopy( sdlRenderer, sdlTexture, NULL, NULL);
                        SDL_RenderPresent( sdlRenderer );
                        //SDL End-----------------------
                    }
                }
                av_free_packet(packet);
            }else{
                //Exit Thread
                thread_exit1=1;
            }
            
        }else if(event.type==SDL_QUIT){
            thread_exit1=1;
        }else if(event.type==SFM_BREAK_EVENT){
            break;
        }
    }
    sws_freeContext(img_convert_ctx);
    
#if OUTPUT_YUV420P
    fclose(fp_yuv);
#endif
    
    SDL_Quit();
    
    av_frame_free(&pFrameYUV);
    av_frame_free(&pFrame);
    avcodec_close(pCodecCtx);
    avformat_close_input(&pformatCtx);
}

#pragma mark 音频
static  Uint8  *audio_chunk;
static  Uint32  audio_len;
static  Uint8  *audio_pos;

void  fill_audio(void *udata,Uint8 *stream,int len){
    //SDL 2.0
    SDL_memset(stream, 0, len);
    if(audio_len==0)		/*  Only  play  if  we  have  data  left  */
        return;
    len=(len>audio_len?audio_len:len);	/*  Mix  as  much  data  as  possible  */
    
    SDL_MixAudio(stream,audio_pos,len,SDL_MIX_MAXVOLUME);
    audio_pos += len;
    audio_len -= len;
}

-(void)audioPlay
{
   
    
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
    
    //SDL
    wanted_spec.freq = out_sample_rate;
    wanted_spec.format = AUDIO_S16SYS;
    wanted_spec.channels = out_channels;
    wanted_spec.silence = 0;
    wanted_spec.samples = out_nb_samples;
    wanted_spec.callback = fill_audio;
    wanted_spec.userdata = pCodecCtx;
    if (SDL_OpenAudio(&wanted_spec, NULL)<0){
        printf("can't open audio.\n");
        return ;
    }
    
    //FIX:Some Codec's Context Information is missing
    in_channel_layout=av_get_default_channel_layout(audioCodecCtx->channels);
    
    //Swr
    au_convert_ctx = swr_alloc();
    au_convert_ctx=swr_alloc_set_opts(au_convert_ctx,out_channel_layout, out_sample_fmt, out_sample_rate,
                                      in_channel_layout,audioCodecCtx->sample_fmt , audioCodecCtx->sample_rate,0, NULL);
    swr_init(au_convert_ctx);
    audioTag = 0;
    //创建音频线程
    SDL_Thread *audio_tid = SDL_CreateThread(sfp_refresh_audio_thread, NULL, NULL);
    SDL_Event audioEvent;
    for (; ;) {
        SDL_WaitEvent(&audioEvent);
        if (audioEvent.type == SFM_AudioRefresh_event) {
            
        }
        if (av_read_frame(pformatCtx, audioPacket) >=0) {
            if (audioPacket->stream_index == audioIndex) {
                audioRet = avcodec_decode_audio4(audioCodecCtx, audioFrame, &audioGot_picture, audioPacket);
                if (ret < 0) {
                    printf("Error in decoding audio frame.\n");
                    return;
                }
                if (audioGot_picture > 0) {
                    swr_convert(au_convert_ctx, &audioOut_buffer, MAX_AUDIO_FRAME_SIZE, (const uint8_t **)audioFrame->data, audioFrame->nb_samples);
                    printf("index:%5d\t pts:%lld\t packet size:%d\n",audioTag,packet->pts,packet->size);
                    audioTag ++;
                }
                
//                while (audio_len >0)
//                    SDL_Delay(1);
                    audio_chunk = audioOut_buffer;
                    audio_len  = out_buffer_size;
                    audio_pos = audio_chunk;
                    //Play
                    SDL_PauseAudio(0);
            }
            av_free_packet(audioPacket);
        }else if (audioEvent.type == SDL_QUIT)
        {
            audio_thread_exit1 = 1;
        }else if (audioEvent.type == SFM_AudioBreak_event)
        {
            break;
        }
    }
    
    swr_free(&au_convert_ctx);
    SDL_CloseAudio();
//    SDL_Quit();
    av_free(audioOut_buffer);
    avcodec_close(audioCodecCtx);
//    avformat_close_input(&pformatCtx);
}


//void render(SDL_Renderer *renderer)
//{
//    
//    Uint8 r, g, b;
//    
//    /* Clear the screen */
//    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
//    SDL_RenderClear(renderer);
//    
//    /*  Come up with a random rectangle */
//    SDL_Rect rect;
//    rect.w = 200;
//    rect.h = 190;
//    rect.x = 20;
//    rect.y = 40;
//    
//    /* Come up with a random color */
//    r = randomInt(50, 255);
//    g = randomInt(50, 255);
//    b = randomInt(50, 255);
//    SDL_SetRenderDrawColor(renderer, r, g, b, 255);//设置渲染器的颜色
//    
//    /*  Fill the rectangle in the color */
//    SDL_RenderFillRect(renderer, &rect);//在渲染区域渲染颜色
//    
//    /* update screen */
//    SDL_RenderPresent(renderer);
//}

//
//-(void)createRectangle
//{
//    SDL_Window *window;
//    SDL_Renderer *renderer;
//    
//    /* initialize SDL */
//    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
//        printf("Could not initialize SDL\n");
//        return;
//    }
//    
//    /* seed random number generator */
//    srand(time(NULL));
//    
//    /* create window and renderer */
//    window =
//    SDL_CreateWindow(NULL, 0, 0, 400, 400,
//                     SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN);
//    if (!window) {
//        printf("Could not initialize Window\n");
//        return ;
//    }
//    
//    renderer = SDL_CreateRenderer(window, -1, 0);
//    if (!renderer) {
//        printf("Could not create renderer\n");
//        return ;
//    }
//    
//    render(renderer);
//    SDL_Delay(1);
//    /* shutdown SDL */
////    SDL_Quit();
//}

//-(void)createGLView
//{
//    _glView = [[OpenglView alloc]init];
//    _glView.backgroundColor = [UIColor greenColor];
//    _glView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-200);
//    [self.view addSubview:_glView];
//    if (self.view.window) {
//         NSLog(@"存在。。。。。。");
//    }else{
//        NSLog(@"不存在。。。。。");
//    }
//   
//    if (self.view.superview) {
//        NSLog(@"存在 superview");
//    }else{
//        NSLog(@"不存在superview");
//    }

//}

//-(Byte *)unshingCharConvertByte:(uint8_t *)src lineSize:(int)linesize width:(int)width height:(int)height
//{
//    width = MIN(linesize, width);
//    NSMutableData *md = [NSMutableData dataWithLength: width * height];
//    Byte *dst = md.mutableBytes;
//    for (NSUInteger i = 0; i < height; ++i) {
//        memcpy(dst, src, width);
//        dst += width;
//        src += linesize;
//    }
//    
//    return md.mutableBytes;
//}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)secondPlay
{
    
}


@end
