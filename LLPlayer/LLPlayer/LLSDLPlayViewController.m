//
//  LLSDLPlayViewController.m
//  LLPlayer
//
//  Created by mac on 16/11/10.
//  Copyright © 2016年 luolei. All rights reserved.
//

#import "LLSDLPlayViewController.h"
#include "SDL.h"

#include <libavformat/avformat.h>
#include <libavutil/mathematics.h>
#include <libavutil/time.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>

#import "OpenglView.h"
#import "OpenGLView20.h"
#import "KxMovieGLView.h"
#import "LLDecoder.h"

#define OUTPUT_YUV420P 0

//Refresh Event
#define REFRESH_EVENT  (SDL_USEREVENT + 1)
//Break
#define BREAK_EVENT  (SDL_USEREVENT + 2)
const int bpp =12;

int screen_w=500,screen_h=500;
const int pixel_w=320,pixel_h=180;

unsigned char buffer[pixel_w*pixel_h*bpp/8];
int thread_exit=0;

int refresh_video(void *opaque){
    thread_exit=0;
    while (thread_exit==0) {
        SDL_Event event;
        event.type = REFRESH_EVENT;
        SDL_PushEvent(&event);
        SDL_Delay(40);
    }
    thread_exit=0;
    //Break
    SDL_Event event;
    event.type = BREAK_EVENT;
    SDL_PushEvent(&event);
    return 0;
}

@interface LLSDLPlayViewController ()
@property (readonly, nonatomic) CGFloat fps;

@end

@implementation LLSDLPlayViewController{
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
    
    OpenglView *_glview;
    OpenGLView20 *_glView20;
    KxMovieGLView *_kxglView;
    CGFloat             _videoTimeBase;
    
    FILE *fp_yuv;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
//    [self sdlShow];
}
- (IBAction)startPlay:(id)sender {
    [self getFrameYUV];
}

-(void)sdlShow
{
    SDL_SetMainReady();//使用官网的需要先执行这句 不然初始化不成功
    if(SDL_Init(SDL_INIT_VIDEO)) {
        printf( "Could not initialize SDL - %s\n", SDL_GetError());
        return ;
    }
    
    SDL_Window *screen;
    //SDL 2.0 Support for multiple windows
    screen = SDL_CreateWindow("Simplest Video Play SDL2", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              screen_w, screen_h,SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE);
    if(!screen) {
        printf("SDL: could not create window - exiting:%s\n",SDL_GetError());
        return ;
    }
    SDL_Renderer* sdlRenderer = SDL_CreateRenderer(screen, -1, 0);
    
    Uint32 pixformat=0;
    //IYUV: Y + U + V  (3 planes)
    //YV12: Y + V + U  (3 planes)
    pixformat= SDL_PIXELFORMAT_IYUV;
    
    SDL_Texture* sdlTexture = SDL_CreateTexture(sdlRenderer,pixformat, SDL_TEXTUREACCESS_STREAMING,pixel_w,pixel_h);
    
    
    FILE *fp=NULL;
            NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"resource" ofType:@"bundle"];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
   NSString *pathString = [bundle pathForResource:@"test_yuv420p_320x180" ofType:@"yuv"];
    
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//     char const *path_cstr = [fileManager fileSystemRepresentationWithPath:pathString];
//    NSLog(@"paths=%s pathString=%@",path_cstr,pathString);
    fp=fopen([pathString UTF8String],"rb+");
    
    if(fp==NULL){
        printf("cannot open this file\n");
        return ;
    }
    
    SDL_Rect sdlRect;
    
    SDL_Thread *refresh_thread = SDL_CreateThread(refresh_video,NULL,NULL);
    SDL_Event event;
    while(1){
        //Wait
        SDL_WaitEvent(&event);
        if(event.type==REFRESH_EVENT){
            if (fread(buffer, 1, pixel_w*pixel_h*bpp/8, fp) != pixel_w*pixel_h*bpp/8){
                // Loop
                fseek(fp, 0, SEEK_SET);
                fread(buffer, 1, pixel_w*pixel_h*bpp/8, fp);
            }
            
            SDL_UpdateTexture( sdlTexture, NULL, buffer, pixel_w);
            
            //FIX: If window is resize
            sdlRect.x = 0;
            sdlRect.y = 0;
            sdlRect.w = screen_w;
            sdlRect.h = screen_h;
            
            SDL_RenderClear( sdlRenderer );
            SDL_RenderCopy( sdlRenderer, sdlTexture, NULL, &sdlRect);
            SDL_RenderPresent( sdlRenderer );
            
        }else if(event.type==SDL_WINDOWEVENT){
            //If Resize
            SDL_GetWindowSize(screen,&screen_w,&screen_h);
        }else if(event.type==SDL_QUIT){
            thread_exit=1;
        }else if(event.type==BREAK_EVENT){
            break;
        }
    }
    SDL_Quit();
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
            printf("find video stream %d\n",i);
            //            break;
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

    
    
    
    screen_w = pCodecCtx->width;
    screen_h = pCodecCtx->height;
    // create window and renderer
    
    
   
    printf("screenw:%d screenh:%d\n",screen_w,screen_h);
    [self videoGLDispaly];
    
}
-(void)videoGLDispaly
{

#if OUTPUT_YUV420P
    fp_yuv=fopen("/Users/mac/Desktop/output.yuv","wb+");
#endif
    _kxglView = [[KxMovieGLView alloc]initWithFrame:self.view.bounds videoWidth:screen_w videoHeight:screen_h];
    _kxglView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.view insertSubview:_kxglView atIndex:0];
    
   AVStream *st = pformatCtx->streams[videoIndex];
    avStreamFPSTimeBase(st, 0.04, &_fps, &_videoTimeBase);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        while (av_read_frame(pformatCtx, packet)>=0){
            if(packet->stream_index==videoIndex){
                ret = avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, packet);
                if(ret < 0){
                    printf("Decode Error.\n");
                    return ;
                }
                if(got_picture){
                   
                    sws_scale(img_convert_ctx, (const uint8_t* const*)pFrame->data, pFrame->linesize, 0, pCodecCtx->height, pFrameYUV->data, pFrameYUV->linesize);
                    //SDL---------------------------
                    //                SDL_UpdateTexture( sdlTexture, NULL, pFrameYUV->data[0], pFrameYUV->linesize[0]);

                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        
                        if (pFrameYUV) {
#if OUTPUT_YUV420P
                            int y_size0=pCodecCtx->width*pCodecCtx->height;
                            fwrite(pFrameYUV->data[0],1,y_size0,fp_yuv);    //Y
                            fwrite(pFrameYUV->data[1],1,y_size0/4,fp_yuv);  //U
                            fwrite(pFrameYUV->data[2],1,y_size0/4,fp_yuv);  //V
#endif

                            
                            KxVideoFrameYUV * yuvFrame = [[KxVideoFrameYUV alloc] init];
                            yuvFrame.width = pCodecCtx->width;
                            yuvFrame.height = pCodecCtx->height;
                            //                        yuvFrame.position = av_frame_get_pkt_duration(<#const AVFrame *frame#>)
                            //                        NSLog(@"width=%d height=%d",pCodecCtx->width,pCodecCtx->height);
                            
                            yuvFrame.luma = copyFrameData(pFrameYUV->data[0],
                                                          pFrameYUV->linesize[0],
                                                          pCodecCtx->width,
                                                          pCodecCtx->height);
                            
                            yuvFrame.chromaB = copyFrameData(pFrameYUV->data[1],
                                                             pFrameYUV->linesize[1],
                                                             pCodecCtx->width / 2,
                                                             pCodecCtx->height / 2);
                            
                            yuvFrame.chromaR = copyFrameData(pFrameYUV->data[2],
                                                             pFrameYUV->linesize[2],
                                                             pCodecCtx->width / 2,
                                                             pCodecCtx->height / 2);
                            
                            [_kxglView render:yuvFrame];
                        }else{
                            NSLog(@"yuv frame is null!!!");
                        }
                       
                    });
                }else{
                    NSLog(@"未获取到图片、丢包");
                }
            }
            sleep(0.9);
        }
        av_free_packet(packet);
        sws_freeContext(img_convert_ctx);
        
#if OUTPUT_YUV420P
        fclose(fp_yuv);
#endif
        av_frame_free(&pFrameYUV);
        av_frame_free(&pFrame);
        avcodec_close(pCodecCtx);
        avformat_close_input(&pformatCtx);

    });
}

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

static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase)
{
    CGFloat fps, timebase;
    
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(st->codec->time_base.den && st->codec->time_base.num)
        timebase = av_q2d(st->codec->time_base);
    else
        timebase = defaultTimeBase;
    
    if (st->codec->ticks_per_frame != 1) {
        NSLog(@"WARNING: st.codec.ticks_per_frame=%d", st->codec->ticks_per_frame);
        //timebase *= st->codec->ticks_per_frame;
    }
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    if (pFPS)
        *pFPS = fps;
    if (pTimeBase)
        *pTimeBase = timebase;
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
