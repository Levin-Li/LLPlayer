//
//  ViewController.m
//  YUVDemo
//
//  Created by luo luo on 24/02/2018.
//  Copyright © 2018 ChangeStrong. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSString *input_str= [NSString stringWithFormat:@"LLResouce.bundle/%@",@"sintel_640_360.yuv"];
    NSString *input_nsstr=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:input_str];
//  int success =  simplest_yuv420_split([input_nsstr UTF8String], 640, 360, 1);
//    simplest_yuv420_gray([input_nsstr UTF8String], 640, 360, 1);
//    simplest_yuv420_halfy([input_nsstr UTF8String], 640, 360, 1);
    simplest_yuv420_border([input_nsstr UTF8String], 640, 360, 15, 10);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//添加白色边框
int simplest_yuv420_border(char *url, int w, int h,int border,int num){
    FILE *fp=fopen(url,"rb+");
    FILE *fp1=fopen("/Users/luoluo/Desktop/videoFiles/output_border.yuv","wb+");
    
    unsigned char *pic=(unsigned char *)malloc(w*h*3/2);
    
    for(int i=0;i<num;i++){
        fread(pic,1,w*h*3/2,fp);
        //Y
        for(int j=0;j<h;j++){
            for(int k=0;k<w;k++){
                //相当于x的值小于borde和大于w-border
                if(k<border||k>(w-border)||j<border||j>(h-border)){
                    pic[j*w+k]=255;
                    //pic[j*w+k]=0;
                }
            }
        }
        fwrite(pic,1,w*h*3/2,fp1);
    }
    
    free(pic);
    fclose(fp);
    fclose(fp1);
    
    return 0;
}

//亮度减半 将Y分量的值减少一半即可
int simplest_yuv420_halfy(char *url, int w, int h,int num){
    FILE *fp=fopen(url,"rb+");
    FILE *fp1=fopen("/Users/luoluo/Desktop/videoFiles/output_half.yuv","wb+");
    
    unsigned char *pic=(unsigned char *)malloc(w*h*3/2);
    
    for(int i=0;i<num;i++){
        fread(pic,1,w*h*3/2,fp);
        //Half
        for(int j=0;j<w*h;j++){
            unsigned char temp=pic[j]/2;
            printf("%d,\n",temp);
            pic[j]=temp;
        }
        fwrite(pic,1,w*h*3/2,fp1);
    }
    
    free(pic);
    fclose(fp);
    fclose(fp1);
    
    return 0;
}

//去掉彩色只留下灰色的Y
int simplest_yuv420_gray(char *url, int w, int h,int num){
    FILE *fp=fopen(url,"rb+");
    FILE *fp1=fopen("/Users/luoluo/Desktop/videoFiles/output_gray.yuv","wb+");
    unsigned char *pic=(unsigned char *)malloc(w*h*3/2);
    
    for(int i=0;i<num;i++){
        fread(pic,1,w*h*3/2,fp);
        //Gray
        memset(pic+w*h,128,w*h/2);//u和v分量 都用颜色为128的无色填充
        fwrite(pic,1,w*h*3/2,fp1);
    }
    
    free(pic);
    fclose(fp);
    fclose(fp1);
    return 0;
}

//取一帧y u v的三张图片  num 帧数
int simplest_yuv420_split(char *url, int w, int h,int num){
    FILE *fp=fopen(url,"rb+");
    FILE *fp1=fopen("/Users/luoluo/Desktop/videoFiles/output_420_y.y","wb+");
    FILE *fp2=fopen("/Users/luoluo/Desktop/videoFiles/output_420_u.y","wb+");
    FILE *fp3=fopen("/Users/luoluo/Desktop/videoFiles/output_420_v.y","wb+");
    
    unsigned char *pic=(unsigned char *)malloc(w*h*3/2);
    
    for(int i=0;i<num;i++){
        
        fread(pic,1,w*h*3/2,fp);//读取整个视频的大小 宽*高*3/2
        //Y
        fwrite(pic,1,w*h,fp1);//占 宽*高这么大
        //U
        fwrite(pic+w*h,1,w*h/4,fp2);//只有Y的 1/4大小
        //V
        fwrite(pic+w*h*5/4,1,w*h/4,fp3);//只有Y的 1/4
    }
    
    free(pic);
    fclose(fp);
    fclose(fp1);
    fclose(fp2);
    fclose(fp3);
    
    return 0;
}
/*************
    y、u、v这些分量的值都是在0-255之间 即1Byte的大小范围  0绿色 128无色 255白色
    色度分量在偏置处理前的取值范围是-128至127，这时候的无色对应的是“0”值。经过偏置后色度分量取值变成了0至255，因而此时的无色对应的就是128了
 一帧yuv格式
 Y占整个视频的 W*H Byte
 U占整个视频的 W*H*1/4
 V占整个视频的 W*H*1/4
 
 一帧RGB格式则为
 R占 W*H
 G占 W*H
 B占 W*H
 
 
 
*/


@end
