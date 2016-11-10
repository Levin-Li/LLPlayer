//
//  LLSDLPlayViewController.m
//  LLPlayer
//
//  Created by mac on 16/11/10.
//  Copyright © 2016年 luolei. All rights reserved.
//

#import "LLSDLPlayViewController.h"
#include "SDL.h"
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

@end

@implementation LLSDLPlayViewController{
    
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
    [self sdlShow];
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

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
