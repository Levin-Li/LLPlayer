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
#include "SDL.h"

//Output YUV420P data as a file
#define OUTPUT_YUV420P 0

@interface ViewController ()

@end
void
fatalError(const char *string)
{
    printf("%s: %s\n", string, SDL_GetError());
//    exit(1);
}
@implementation ViewController{
    AVFormatContext *pformatCtx;
    int videoIndex;
    AVCodecContext *pCodecCtx;
    AVCodec *pCodec;
    AVFrame *pFrame,*pFrameYUV;
    uint8_t *out_buffer;
    AVPacket *packet;
    int y_size;
    int ret,got_picture;
    struct SwsContext *img_convert_ctx;
    
    //SDL
    //SDL---------------------------
    int screen_w,screen_h;
    SDL_Window *screen;
    SDL_Renderer* sdlRenderer;
    SDL_Texture* sdlTexture;
    SDL_Rect sdlRect;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self getFrameYUV];
}

-(void)getFrameYUV
{
    NSString *input_str= [NSString stringWithFormat:@"resource.bundle/%@",@"sintel.h264"];
    NSString *input_nsstr=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:input_str];
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
    }
    
    if (videoIndex == -1) {
        printf("Didn't find avideo stream");
    }
    
    pCodecCtx=pformatCtx->streams[videoIndex]->codec;
    pCodec=avcodec_find_decoder(pCodecCtx->codec_id);
    
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
    
    
    //init Frame
    pFrame = av_frame_alloc();
    pFrameYUV = av_frame_alloc();
        //分配输出内存空间
//    out_buffer = (uint8_t *)av_malloc(avpicture_get_size(PIX_FMT_YUV420P, pCodecCtx->width, pCodecCtx->height));
//    avpicture_fill((AVPicture *)pFrameYUV, out_buffer, PIX_FMT_YUV420P, pCodecCtx->width, pCodecCtx->height);//分配内存空间
    out_buffer=(unsigned char *)av_malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P,  pCodecCtx->width, pCodecCtx->height,1));
    av_image_fill_arrays(pFrameYUV->data, pFrameYUV->linesize,out_buffer,
                         AV_PIX_FMT_YUV420P,pCodecCtx->width, pCodecCtx->height,1);
    packet = (AVPacket *)av_malloc(sizeof(AVPacket));//
    //Output Info-----------------------------
    printf("--------------- File Information ----------------\n");
    av_dump_format(pformatCtx, 0, [input_nsstr UTF8String], 0);
    printf("-------------------------------------------------\n");
    img_convert_ctx = sws_getContext(pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt,
                                     pCodecCtx->width, pCodecCtx->height, PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);//转码的信息

    
    //SDL----------------------------
    if(SDL_Init(SDL_INIT_VIDEO)< 0) {
        printf( "Could not initialize SDL - %s\n", SDL_GetError());
        return ;
    }
    
    screen_w = pCodecCtx->width;
    screen_h = pCodecCtx->height;
    /* create window and renderer */
   
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
    
    //SDL End----------------------
    
    while(av_read_frame(pformatCtx, packet)>=0){
        if(packet->stream_index==videoIndex){
            ret = avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, packet);
            if(ret < 0){
                printf("Decode Error.\n");
                return;
            }
            if(got_picture){
                sws_scale(img_convert_ctx, (const unsigned char* const*)pFrame->data, pFrame->linesize, 0, pCodecCtx->height,
                          pFrameYUV->data, pFrameYUV->linesize);
                
#if OUTPUT_YUV420P
                y_size=pCodecCtx->width*pCodecCtx->height;
                fwrite(pFrameYUV->data[0],1,y_size,fp_yuv);    //Y
                fwrite(pFrameYUV->data[1],1,y_size/4,fp_yuv);  //U
                fwrite(pFrameYUV->data[2],1,y_size/4,fp_yuv);  //V
#endif
                //SDL---------------------------
                
#if 1
                SDL_UpdateTexture( sdlTexture, NULL, pFrameYUV->data[0], pFrameYUV->linesize[0] );
#else
                SDL_UpdateTextureYUV(sdlTexture, &sdlRect,
                                     pFrameYUV->data[0], pFrameYUV->linesize[0],
                                     pFrameYUV->data[1], pFrameYUV->linesize[1],
                                     pFrameYUV->data[2], pFrameYUV->linesize[2]);
#endif
                
                SDL_RenderClear( sdlRenderer );
                SDL_RenderCopy( sdlRenderer, sdlTexture,  NULL, &sdlRect);
                SDL_RenderPresent( sdlRenderer );
                //SDL End-----------------------
                //Delay 40ms
                SDL_Delay(40);
            }
        }  
        av_free_packet(packet);  
    }
    
    //flush decoder
    //FIX: Flush Frames remained in Codec
    while (1) {
        ret = avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, packet);
        if (ret < 0)
            break;
        if (!got_picture)
            break;
        sws_scale(img_convert_ctx, (const unsigned char* const*)pFrame->data, pFrame->linesize, 0, pCodecCtx->height,
                  pFrameYUV->data, pFrameYUV->linesize);
#if OUTPUT_YUV420P
        int y_size=pCodecCtx->width*pCodecCtx->height;
        fwrite(pFrameYUV->data[0],1,y_size,fp_yuv);    //Y
        fwrite(pFrameYUV->data[1],1,y_size/4,fp_yuv);  //U
        fwrite(pFrameYUV->data[2],1,y_size/4,fp_yuv);  //V
#endif
        //SDL---------------------------
        SDL_UpdateTexture( sdlTexture, &sdlRect, pFrameYUV->data[0], pFrameYUV->linesize[0] );
        SDL_RenderClear( sdlRenderer );
        SDL_RenderCopy( sdlRenderer, sdlTexture,  NULL, &sdlRect);
        SDL_RenderPresent( sdlRenderer );
        //SDL End-----------------------
        //Delay 40ms
        SDL_Delay(40);
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
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
