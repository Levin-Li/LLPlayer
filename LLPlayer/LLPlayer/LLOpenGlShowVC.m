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

//主线程
#define GCDMain(block)       dispatch_async(dispatch_get_main_queue(),block)
///GCD，获取一个全局队列
#define GCDBackground(block) dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block)

@interface LLOpenGlShowVC ()<MediaDecoderProtocl>
@property(nonatomic,strong)LLMediaDecoder *decoder;
@property (weak, nonatomic) IBOutlet UIView *playView;

@end

@implementation LLOpenGlShowVC{
   
    
    LLMediaGLView *_kxglView;
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
    
}
- (IBAction)startActon:(UIButton *)sender {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSString *input_str= [NSString stringWithFormat:@"resource.bundle/%@",@"war3end.mp4"];//war3end.mp4  sintel.h264
        NSString *input_nsstr=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:input_str];
        
        //开始播放
        self.decoder = [[LLMediaDecoder alloc]init];
        self.decoder.delegete = self;
        [self.decoder openFile:input_nsstr];
        
    });
    
    
}

-(void)showYuvFrame:(LLMediaDecoder *)decoer
{
   
        if (decoer) {
            //主线程刷新
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                GCDMain(^{
                    NSLog(@"init opengl view.width:%lu height:%lu",self.decoder.yuvframes.firstObject.width,self.decoder.yuvframes.firstObject.height);
                    //初始化用来显示的view
                    CGFloat width = self.playView.bounds.size.width;
                    CGFloat height = self.playView.bounds.size.width*(self.decoder.yuvframes.firstObject.height/(float)self.decoder.yuvframes.firstObject.width);
                    _kxglView = [[LLMediaGLView alloc]initWithFrame:self.playView.bounds videoWidth:width videoHeight:height];
                    _kxglView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
                    [self.playView insertSubview:_kxglView atIndex:0];
                });
                
            });
            
                [self showFrame];
        }else{
            NSLog(@"erro no decoder !!!");
        }
    
    
}

-(void)showFrame
{
    GCDMain(^{
        if (self.decoder.yuvframes.count > 0) {
            LLVideoFrameYUV *frame = [self.decoder.yuvframes firstObject];
            
            NSDate *currentdate = [NSDate date];
            NSTimeInterval interval = [currentdate timeIntervalSinceDate:self.decoder.startDate];
            if (interval >= frame.timestamp) {
                //延迟时间大于3秒 丢弃部分帧
                if (interval > 1.0) {
                    NSLog(@"frame delay over %f seconds !!!",interval);
                }
                
                //显示
                NSLog(@"LLtimestamp:%f yuvcounts:   %d",frame.timestamp,self.decoder.yuvframes.count);
                [_kxglView render:frame];
                [self.decoder.yuvframes removeObjectAtIndex:0];
                //显示下一帧
                //              [self showFrame];
                
                
                
            }else{
                //还没到帧显示的时间
                NSTimeInterval sleeptime = frame.timestamp - interval;
                NSLog(@"sleep time:%f",sleeptime);
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
