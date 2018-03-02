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
//#import "LLAudioOutPutQueue.h"
#import "LLAudioQueuePlayer.h"


@interface LLOpenGlShowVC ()<MediaDecoderProtocl>
@property(nonatomic,strong)LLMediaDecoder *decoder;
@property (weak, nonatomic) IBOutlet UIView *playView;
@property(nonatomic,strong)NSMutableArray <LLVideoFrameYUV *> *videoFrames;
@property(nonatomic,strong)NSMutableArray <LLAudioFrame *> *audioFrames;
@property(nonatomic,assign)NSUInteger totalBuffDuration;

@property(nonatomic,strong)NSMutableArray *cacheAudioDatas;
@end

@implementation LLOpenGlShowVC{
   
    
    LLMediaGLView *_kxglView;
    CGFloat             _videoTimeBase;
    
    FILE *fp_yuv;
//    LLAudioOutPutQueue *_audioPlayer;
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

-(NSMutableArray *)cacheAudioDatas
{
    if (!_cacheAudioDatas) {
        _cacheAudioDatas = [[NSMutableArray alloc]init];
    }
    return _cacheAudioDatas;
}

//-(void)addAudioData:(NSData *)data
//{
//    [self.cacheAudioDatas addObject:data];
//    if (self.cacheAudioDatas.count > 50.0 ) {
//        LLAudioQueuePlayer *player = [LLAudioQueuePlayer sharedInstance];
//        [player.receiveData addObjectsFromArray:self.cacheAudioDatas];
////        [_audioPlayer.receiveData addObjectsFromArray:self.cacheAudioDatas];
//        [self.cacheAudioDatas removeAllObjects];
//    }
//
//
//}

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
//    LLAudioQueuePlayer *player = [LLAudioQueuePlayer sharedInstance];
//    [player startPlay];
    
    [self startPlay];
}






-(void)startPlay
{
    //音频
    GCDMain(^{
        if (self.audioFrames.count > 0) {
            //播放一帧音频数据
            LLAudioFrame *audioframe = [self.audioFrames firstObject];
            LLAudioQueuePlayer *player = [LLAudioQueuePlayer sharedInstance];
            [player.receiveData addObject:audioframe.samples];
            [self.audioFrames removeObjectAtIndex:0];
            self.totalBuffDuration -= audioframe.duration;
//            NSLog(@"audioFrameDuration:%f",audioframe.duration);//0.023220
            //开始播放视频
            [self showVideoFramePosition:audioframe.timestamp duration:audioframe.duration/2.0];
        }else{
            NSLog(@" Play end .");
        }
        
    });
    
    
    
}

-(void)showVideoFramePosition:(CGFloat)position duration:(CGFloat)duration
{
    if (self.totalBuffDuration < LLMinCacheDutation/2.0) {
        //小于一半的缓存时间继续解码
        CGFloat addDuration = LLMinCacheDutation - self.totalBuffDuration;
        [self.decoder startDecodeDuration:addDuration];
    }
    //视频
    GCDBackground(^{
        if (self.videoFrames.count > 0) {
            LLVideoFrameYUV *frame = [self.videoFrames firstObject];
            
            if (frame.timestamp > (position+duration)) {
                //还没到显示此视频帧的时间
                CGFloat delayTime = duration;
                NSLog(@"delay %f seconds play next audio frame",delayTime);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self startPlay];
                });
            }else if (frame.timestamp >= position  && frame.timestamp <= (position+duration)) {
                //正常显示
                NSLog(@"CurrentVideoFrametimestamp:%f framesCounts:   %lu",frame.timestamp,(unsigned long)self.videoFrames.count);
                GCDMain(^{
                    [_kxglView render:frame];
                    [self.videoFrames removeObjectAtIndex:0];
                    self.totalBuffDuration -= frame.duration;
                });
                //延迟此帧需要的持续时间后显示下一帧
                CGFloat delayTime = MIN(duration, frame.duration);
               
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (frame.duration < duration) {
                        [self showVideoFramePosition:position+frame.duration duration:duration-frame.duration];
                    }else{
                         NSLog(@"delay %f seconds play next audio frame2",delayTime);//0.011610
                        [self startPlay];
                    }
                    
                });
            }else if (frame.timestamp < position)
            {
                //此帧过时了 直接加快显示
                NSLog(@"delay %f seconds to present frame !",position-frame.timestamp);
                GCDMain(^{
                    [_kxglView render:frame];
                    [self.videoFrames removeObjectAtIndex:0];
                    self.totalBuffDuration -=frame.duration;
                    //直接播放下一帧视频
                    [self showVideoFramePosition:position duration:duration];
                });
            }
            
        }else{
            NSLog(@"no more frames to show delay 5 seconds");
            if (self.totalBuffDuration < LLMinCacheDutation) {
                CGFloat addDuration = LLMinCacheDutation - self.totalBuffDuration;
                [self.decoder startDecodeDuration:addDuration];
            }
            
            
        }
    });
}

#pragma mark MediaDecoderProtocl
-(void)initAudioPlayer:(AudioStreamBasicDescription)audioFormat
{
    GCDMain(^{
        LLAudioQueuePlayer *player = [LLAudioQueuePlayer sharedInstance];
         [player  setAudioFormat:audioFormat];
        [player startPlay];
//        _audioPlayer = [[LLAudioOutPutQueue alloc]init];
//        [_audioPlayer registAudio:audioFormat];
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
                        self.totalBuffDuration += frame.duration;
                    }else if ([self.decoder isValidtyAudio] && frame.type == LLMediaFrameTypeAudio ){
                        [self.audioFrames addObject:(LLAudioFrame *)frame];
                        self.totalBuffDuration += frame.duration;
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
