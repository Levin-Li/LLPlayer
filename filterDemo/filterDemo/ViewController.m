//
//  ViewController.m
//  filterDemo
//
//  Created by luo luo on 2018/4/13.
//  Copyright © 2018年 ChangeStrong. All rights reserved.
//

#import "ViewController.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavfilter/avfiltergraph.h>
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/avutil.h>
#include <libavutil/imgutils.h>

@interface ViewController ()

@end

@implementation ViewController

static int XError(int errNum)
{
    char buf[1024] = { 0 };
    av_strerror(errNum, buf, sizeof(buf));
    NSLog(@"error:%s",buf);
    getchar();
    return -1;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self addFilter];
}

-(void)addFilter
{
    int ret;
    AVFrame *frame_in;
    AVFrame *frame_out;
    unsigned char *frame_buffer_in;
    unsigned char *frame_buffer_out;
    
    AVFilterContext *buffersink_ctx;
    AVFilterContext *buffersrc_ctx;
    AVFilterGraph *filter_graph;
//    static int video_stream_index = -1;
    
    NSString *input_str= [NSString stringWithFormat:@"videoResource.bundle/%@",@"sintel_640_360.yuv"];
    NSString *input_nsstr=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:input_str];
    
    //Input YUV  sintel_640_360.yuv
    FILE *fp_in=fopen([input_nsstr UTF8String],"rb+");
    if(fp_in==NULL){
        printf("Error open input file.\n");
        return ;
    }
    int in_width=640;
    int in_height=360;
    
    //Output YUV
    FILE *fp_out=fopen("/Users/luoluo/Desktop/videoFiles/output.yuv","wb+");
    if(fp_out==NULL){
        printf("Error open output file.\n");
        return ;
    }
    
    //滤镜类型
    //const char *filter_descr = "lutyuv='u=128:v=128'";
//    const char *filter_descr = "boxblur";
    //const char *filter_descr = "hflip";
//    const char *filter_descr = "hue='h=60:s=-3'";
    //const char *filter_descr = "crop=2/3*in_w:2/3*in_h";
//    const char *filter_descr = "drawbox=x=100:y=100:w=100:h=100:color=pink@0.5";
//    const char *filter_descr = "drawtext=fontfile=arial.ttf:fontcolor=green:fontsize=30:text='liguangluo'";
    
    NSString *input_str2= [NSString stringWithFormat:@"videoResource.bundle/%@",@"logo.png"];
    NSString *input_nsstr2=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:input_str2];
    NSString *filterDescrPath = [NSString stringWithFormat:@"movie=%@[logo];[in][logo]overlay=10:10[out]",input_nsstr2];
    const char *filter_descr = [filterDescrPath UTF8String];
    
    avfilter_register_all();
    
    char args[512];
    AVFilter *buffersrc  = avfilter_get_by_name("buffer");
    AVFilter *buffersink = avfilter_get_by_name("buffersink");
    AVFilterInOut *outputs = avfilter_inout_alloc();//用来存放输出滤镜上下文
    AVFilterInOut *inputs  = avfilter_inout_alloc();//用来存放输入滤镜上下文
    enum AVPixelFormat pix_fmts[] = { AV_PIX_FMT_YUV420P, AV_PIX_FMT_NONE };
    AVBufferSinkParams *buffersink_params;
    
    //创建虑镜图
     filter_graph = avfilter_graph_alloc();
    
    //将输入帧的相关信息存入buff  然后存入滤镜图的输入上下文
    snprintf(args, sizeof(args),
             "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
             in_width,in_height,AV_PIX_FMT_YUV420P,
             1, 25,1,1);
    //利用滤镜图创建滤镜的输入上下文
    ret = avfilter_graph_create_filter(&buffersrc_ctx, buffersrc, "in",
                                       args, NULL, filter_graph);
    if (ret < 0) {
        
        printf("Cannot create buffer source\n");
        return;
    }
    
    //利用滤镜图创建输出滤镜上下文
    buffersink_params = av_buffersink_params_alloc();
    buffersink_params->pixel_fmts = pix_fmts;//设置经过滤镜处理后的输出格式
    ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out",
                                       NULL, buffersink_params, filter_graph);
    av_free(buffersink_params);
    if (ret < 0) {
        XError(ret);
        printf("Cannot create buffer sink\n");
        return ;
    }
    
    
    /* Endpoints for the filter graph. */
    outputs->name       = av_strdup("in");
    outputs->filter_ctx = buffersrc_ctx;
    outputs->pad_idx    = 0;
    outputs->next       = NULL;
    
    inputs->name       = av_strdup("out");
    inputs->filter_ctx = buffersink_ctx;
    inputs->pad_idx    = 0;
    inputs->next       = NULL;
    //绑定滤镜输入输出上下文、滤镜类型到滤镜图中
    if ((ret = avfilter_graph_parse_ptr(filter_graph, filter_descr,
                                        &inputs, &outputs, NULL)) < 0)
        return ;
    //开始配置滤镜图
    if ((ret = avfilter_graph_config(filter_graph, NULL)) < 0)
        return ;
    //输入帧
    frame_in = av_frame_alloc();
    //申请一块存放一帧视频的buff
    frame_buffer_in = (unsigned char *)av_malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P, in_width,in_height,1));
    av_image_fill_arrays(frame_in->data, frame_in->linesize,frame_buffer_in,
                         AV_PIX_FMT_YUV420P,in_width, in_height,1);
    
    //输出帧
    frame_out=av_frame_alloc();
    frame_buffer_out=(unsigned char *)av_malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P, in_width,in_height,1));
    av_image_fill_arrays(frame_out->data, frame_out->linesize,frame_buffer_out,
                         AV_PIX_FMT_YUV420P,in_width, in_height,1);
    
    frame_in->width=in_width;
    frame_in->height=in_height;
    frame_in->format=AV_PIX_FMT_YUV420P;
    
    while (1) {
        //从文件中读取一帧yuv数据
        if(fread(frame_buffer_in, 1, in_width*in_height*3/2, fp_in)!= in_width*in_height*3/2){
            break;
        }
        //input Y,U,V
        frame_in->data[0]=frame_buffer_in;
        frame_in->data[1]=frame_buffer_in+in_width*in_height;
        frame_in->data[2]=frame_buffer_in+in_width*in_height*5/4;
        //添加一帧数据到滤镜输入上下文中
        if (av_buffersrc_add_frame(buffersrc_ctx, frame_in) < 0) {
            printf( "Error while add frame.\n");
            break;
        }
        
        //拉取一张经过滤镜处理的图片从滤镜库中
        ret = av_buffersink_get_frame(buffersink_ctx, frame_out);
        if (ret < 0)
            break;
        
        //output Y,U,V
        if(frame_out->format==AV_PIX_FMT_YUV420P){
            for(int i=0;i<frame_out->height;i++){
                fwrite(frame_out->data[0]+frame_out->linesize[0]*i,1,frame_out->width,fp_out);
            }
            for(int i=0;i<frame_out->height/2;i++){
                fwrite(frame_out->data[1]+frame_out->linesize[1]*i,1,frame_out->width/2,fp_out);
            }
            for(int i=0;i<frame_out->height/2;i++){
                fwrite(frame_out->data[2]+frame_out->linesize[2]*i,1,frame_out->width/2,fp_out);
            }
        }
        printf("Process 1 frame!\n");
        av_frame_unref(frame_out);
    }
    
    fclose(fp_in);
    fclose(fp_out);
    
    av_frame_free(&frame_in);
    av_frame_free(&frame_out);
    avfilter_graph_free(&filter_graph);
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
