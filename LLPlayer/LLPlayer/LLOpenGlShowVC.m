//
//  LLOpenGlShowVC.m
//  LLPlayer
//
//  Created by luo luo on 19/10/2017.
//  Copyright © 2017 luolei. All rights reserved.
//

#import "LLOpenGlShowVC.h"

#import "LLMediaDecoder.h"
#import "LLMediaGLView.h"
#import "LLAudioOutPutQueue.h"

//主线程
#define GCDMain(block)       dispatch_async(dispatch_get_main_queue(),block)
///GCD，获取一个全局队列
#define GCDBackground(block) dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block)

@interface LLOpenGlShowVC ()<MediaDecoderProtocl>
@property(nonatomic,strong)LLMediaDecoder *decoder;
@property (weak, nonatomic) IBOutlet UIView *playView;
@property(nonatomic,strong)NSMutableArray <LLVideoFrameYUV *> *videoFrames;
@property(nonatomic,strong)NSMutableArray <LLAudioFrame *> *audioFrames;

@end

@implementation LLOpenGlShowVC{
   
    
    LLMediaGLView *_kxglView;
    CGFloat             _videoTimeBase;
    
    FILE *fp_yuv;
    LLAudioOutPutQueue *_audioPlayer;
}

-(NSMutableArray <LLVideoFrameYUV *> *)videoFrames
{
    if (!_videoFrames) {
        _videoFrames = [[NSMutableArray alloc]init];
    }
    return _videoFrames;
}

-(NSMutableArray <LLAudioFrame *>*)audioFrames
{
    if (!_audioFrames) {
        _audioFrames = [[NSMutableArray alloc]init];
    }
    return _audioFrames;
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
    //初始化相关
    [self initDecoder];
}

-(void)initDecoder
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSString *input_str= [NSString stringWithFormat:@"resource.bundle/%@",@"war3end.mp4"];//war3end.mp4  sintel.h264
        NSString *input_nsstr=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:input_str];
        
        //开始播放
        self.decoder = [[LLMediaDecoder alloc]init];
        self.decoder.delegete = self;
        [self.decoder openFile:input_nsstr];
        
    });
}

- (IBAction)startActon:(UIButton *)sender {
    
    NSLog(@"开始播放!");
    [self showFrame];
}






-(void)showFrame
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        LLLog(@"start time .");
        self.decoder.startDate = [NSDate date];
    });
    
    GCDBackground(^{
        if (self.videoFrames.count > 0) {
            LLVideoFrameYUV *frame = [self.videoFrames firstObject];
            
            NSDate *currentdate = [NSDate date];
            NSTimeInterval interval = [currentdate timeIntervalSinceDate:self.decoder.startDate];
            if (interval >= frame.timestamp) {
                //延迟时间大于3秒 丢弃部分帧
                if (interval > 1.0) {
                    NSLog(@"frame delay over %f seconds !!!",interval-frame.timestamp);
                }
                
                //显示
                NSLog(@"CurrentFrametimestamp:%f timer:%f framesCounts:   %lu",frame.timestamp,interval,(unsigned long)self.videoFrames.count);
                GCDMain(^{
                    [_kxglView render:frame];
                    [self.videoFrames removeObjectAtIndex:0];
                });
                //延迟此帧需要的持续时间后显示下一帧
                CGFloat duration = frame.duration>0?frame.duration:0;
                NSLog(@"延迟%f播放下一帧",duration);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    //显示下一帧
                    [self showFrame];
                });
            }else{
                //还没到帧显示的时间
                NSTimeInterval sleeptime = frame.timestamp - interval;
                NSLog(@"Need sleep time:%f",sleeptime);
                //                [NSThread sleepForTimeInterval:sleeptime];
                //                [self showFrame];
            }
        }else{
            NSLog(@"no more frame to show delay 5 seconds");
            //        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            //            [self showFrame];
            //        });
        }
    });
    
    
}
#pragma mark MediaDecoderProtocl
-(void)initAudioPlayer:(AudioStreamBasicDescription)audioFormat
{
    GCDMain(^{
        _audioPlayer = [[LLAudioOutPutQueue alloc]init];
        [_audioPlayer registAudio:audioFormat];
    });
}
-(void)initOpenglView
{
    //主线程刷新
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        GCDMain(^{
            NSLog(@"init opengl view.width:%lu height:%lu",self.decoder.width,self.decoder.height);
            //初始化用来显示的view
            CGFloat width = self.playView.bounds.size.width;
            CGFloat height = self.playView.bounds.size.width*(self.decoder.height/(float)self.decoder.width);
            _kxglView = [[LLMediaGLView alloc]initWithFrame:self.playView.bounds videoWidth:width videoHeight:height];
            _kxglView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
            [self.playView insertSubview:_kxglView atIndex:0];
        });
        
    });
}
//添加新帧
-(void)addNewFrames
{
    if (self.decoder && self.decoder.frames.count > 0) {
        if ([self.decoder isValidtyVideo]) {
            
            @synchronized(self.videoFrames) {
                
                for (LLMediaFrame *frame in self.decoder.frames)
                    if (frame.type == LLMediaFrameTypeVideo) {
                        [self.videoFrames addObject:(LLVideoFrameYUV *)frame];
//                        _bufferedDuration += frame.duration;
                    }else if ([self.decoder isValidtyAudio] && frame.type == LLMediaFrameTypeAudio ){
                        [self.audioFrames addObject:(LLAudioFrame *)frame];
                    }
                
            }
        }
        
        
        
    }else{
        NSLog(@"not get new frame !!!");
    }
}

-(void)showFirsKeyYuvFrame:(LLVideoFrameYUV *)yuvFrame
{
   
        if (yuvFrame && yuvFrame.luma.length >0) {
            GCDMain(^{
                //首帧直接显示
                [_kxglView render:yuvFrame];
                
                
            });
        }else{
            NSLog(@"first frame present failture error no data !!!");
        }
    
    
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
