//
//  ViewController.m
//  PushFFmpeg3_4Demo
//
//  Created by luo luo on 29/03/2018.
//  Copyright © 2018 ChangeStrong. All rights reserved.
//

#import "ViewController.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/time.h>
#include <libavutil/avutil.h>
#include <libavutil/mathematics.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *pushButton;

@end

@implementation ViewController
- (IBAction)startPushAction:(id)sender {
    [self pushSteam];
}

static int XError(int errNum)
{
    char buf[1024] = { 0 };
    av_strerror(errNum, buf, sizeof(buf));
    NSLog(@"error:%s",buf);
    getchar();
    return -1;
}
//获取时间戳
static double r2d(AVRational r)
{
    return r.num == 0 || r.den == 0 ? 0. : (double)r.num / (double)r.den;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}



-(void)pushSteam
{
    NSString *input_str= [NSString stringWithFormat:@"videoResource.bundle/%@",@"uvcut.flv"];
    NSString *input_nsstr=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:input_str];
   const char *inUrl = [input_nsstr UTF8String];
    char *outUrl = "rtmp://192.168.1.103:1936/zbcs/room";
    av_register_all();
    avformat_network_init();
    AVFormatContext *ictx = NULL;
    //创建输入AVFormatContext
    int re = avformat_open_input(&ictx, inUrl, 0, 0);
    if (re != 0)
    {
        XError(re);
        return;
    }

    re = avformat_find_stream_info(ictx, 0);

    if (re != 0)
    {
        XError(re);
        return;
    }
    av_dump_format(ictx, 0, inUrl, 0);

    //创建输出AVFormatContext
    AVFormatContext *octx = NULL;
    re = avformat_alloc_output_context2(&octx, 0, "flv", outUrl);
    if (!octx)
    {
        XError(re);
        return;
    }

    for (int i = 0; i < ictx->nb_streams; i++)
    {
        //创建AVStream 并绑定到AVFormatContext
        AVStream *outS = avformat_new_stream(octx, ictx->streams[i]->codec->codec);
        if (!outS)
        {
            XError(0);
            return;
        }
        //从输入流中copy相关编码器相关信息
        re = avcodec_parameters_copy(outS->codecpar, ictx->streams[i]->codecpar);
        outS->codec->codec_tag = 0;
    }
    av_dump_format(octx, 0, outUrl, 1);
    //创建AVIOContext 且已绑定到AVFormatContext
    re = avio_open(&octx->pb, outUrl, AVIO_FLAG_WRITE);
    if (!octx->pb)
    {
         XError(re);
        return;
    }
    //将视频流信息填充好(包括格式、宽、高、帧率等)
    re = avformat_write_header(octx, 0);
    if (re < 0)
    {
       XError(re);
        return ;
    }
    
    AVPacket pkt;
    long long startTime = av_gettime();
    
    for (;;)
    {
        //从输入上下文中读取一个AVPacket
        re = av_read_frame(ictx, &pkt);
        if (re != 0)
        {
            break;
        }
        
        AVRational itime = ictx->streams[pkt.stream_index]->time_base;
        AVRational otime = octx->streams[pkt.stream_index]->time_base;
//        NSLog(@"原dts=%lld",pkt.dts);
        //可能存在输入上下文得到的时间戳和输出默认的时间戳不一致  所以转换一下
        pkt.pts = av_rescale_q_rnd(pkt.pts, itime, otime, (AV_ROUND_NEAR_INF | AV_ROUND_NEAR_INF));
        pkt.dts = av_rescale_q_rnd(pkt.dts, itime, otime, (AV_ROUND_NEAR_INF | AV_ROUND_NEAR_INF));
        NSLog(@"dts=%lld",pkt.dts);
        pkt.duration = av_rescale_q_rnd(pkt.duration, itime, otime, (AV_ROUND_NEAR_INF | AV_ROUND_NEAR_INF));
        pkt.pos = -1;
        
        if (ictx->streams[pkt.stream_index]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO)
        {
            AVRational tb = ictx->streams[pkt.stream_index]->time_base;
            
            long long now = av_gettime() - startTime;//微秒
            long long dts = 0;
            dts = pkt.dts * (1000 * 1000 * r2d(tb));//timebase是秒
            if (dts > now)
                av_usleep(dts - now);
        }
        //开始推流这一个包
        re = av_interleaved_write_frame(octx, &pkt);
        if (re<0)
        {
           XError(re);
            return ;
        }
    }
    
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
