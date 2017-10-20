//
//  LLMediaGLView.h
//  LLPlayer
//
//  Created by luo luo on 19/10/2017.
//  Copyright © 2017 luolei. All rights reserved.
//

#import <UIKit/UIKit.h>
@class LLVideoFrame;

@interface LLMediaGLView : UIView
- (id) initWithFrame:(CGRect)frame videoWidth:(float)width videoHeight:(float)height;

- (void) render: (LLVideoFrame *) frame;
@end
