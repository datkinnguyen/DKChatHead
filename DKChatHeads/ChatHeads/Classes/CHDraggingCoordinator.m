//
//  CHDraggingCoordinator.m
//  ChatHeads
//
//  Created by Matthias Hochgatterer on 4/19/13.
//  Copyright (c) 2013 Matthias Hochgatterer. All rights reserved.
//
//  Updated by Dat Nguyen on 5/08/13
//  Add support for Dismissing chat heads like Facebook app
//


#import "CHDraggingCoordinator.h"
#import <QuartzCore/QuartzCore.h>
#import "CHDraggableView.h"


#ifdef __IPHONE_6_0
# define ALIGN_CENTER NSTextAlignmentCenter
#else
# define ALIGN_CENTER UITextAlignmentCenter
#endif

#define kDismissViewHeight                  80.0f
#define kDismissViewHeightZoomInsect        5.0f 
#define kDismissViewHeightZoomInsectBounce  5.0f

#define kDismissViewLabelButtonSpace        5.0f
#define kDismissViewLabelHeight             30.0f
#define kDismissViewLabelFontSize           18.0f
#define kDismissViewAnimationBounce         10.0f

#define kDismissViewButtonXTag              2


#define kDismissButtonHeight                (kDismissViewHeight - kDismissViewHeightZoomInsect*2)

typedef enum {
    CHInteractionStateNormal,
    CHInteractionStateConversation,
    CHInteractionStateReadyToDismiss
} CHInteractionState;

@interface CHDraggingCoordinator ()

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSMutableDictionary *edgePointDictionary;;
@property (nonatomic, assign) CGRect draggableViewBounds;
@property (nonatomic, assign) CHInteractionState state;
@property (nonatomic, assign) CHInteractionState previousState;
@property (nonatomic, strong) UINavigationController *presentedNavigationController;
@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *dismissAreaView;
@property (nonatomic, assign) CGRect buttonXFrame;


@end

@implementation CHDraggingCoordinator

- (id)initWithWindow:(UIWindow *)window draggableViewBounds:(CGRect)bounds
{
    self = [super init];
    if (self) {
        _window = window;
        _draggableViewBounds = bounds;
        _state = CHInteractionStateNormal;
        _previousState = _state;
        _edgePointDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Geometry

- (CGRect)_dropArea
{
    return CGRectInset([self.window.screen applicationFrame], -(int)(CGRectGetWidth(_draggableViewBounds)/6), 0);
}

- (CGRect)_conversationArea
{
    CGRect slice;
    CGRect remainder;
    CGRectDivide([self.window.screen applicationFrame], &slice, &remainder, CGRectGetHeight(CGRectInset(_draggableViewBounds, 10, 0)), CGRectMinYEdge);
    return slice;
}

- (CGRectEdge)_destinationEdgeForReleasePointInCurrentState:(CGPoint)releasePoint
{
    if (_state == CHInteractionStateConversation) {
        return CGRectMinYEdge;
    } else if(_state == CHInteractionStateNormal) {
        return releasePoint.x < CGRectGetMidX([self _dropArea]) ? CGRectMinXEdge : CGRectMaxXEdge;
    }
    NSAssert(false, @"State not supported");
    return CGRectMinYEdge;
}

- (CGPoint)_destinationPointForReleasePoint:(CGPoint)releasePoint
{
    CGRect dropArea = [self _dropArea];
    
    CGFloat midXDragView = CGRectGetMidX(_draggableViewBounds);
    CGRectEdge destinationEdge = [self _destinationEdgeForReleasePointInCurrentState:releasePoint];
    CGFloat destinationX;
    CGFloat destinationY = MAX(releasePoint.y, CGRectGetMinY(dropArea) + CGRectGetMidY(_draggableViewBounds));

    if (self.snappingEdge == CHSnappingEdgeBoth){   //ChatHead will snap to both edges
        if (destinationEdge == CGRectMinXEdge) {
            destinationX = CGRectGetMinX(dropArea) + midXDragView;
        } else {
            destinationX = CGRectGetMaxX(dropArea) - midXDragView;
        }
        
    }else if(self.snappingEdge == CHSnappingEdgeLeft){  //ChatHead will snap only to left edge
        destinationX = CGRectGetMinX(dropArea) + midXDragView;
        
    }else{  //ChatHead will snap only to right edge
        destinationX = CGRectGetMaxX(dropArea) - midXDragView;
    }

    return CGPointMake(destinationX, destinationY);
}

#pragma mark - Dragging

- (void)draggableViewHold:(CHDraggableView *)view
{
    
}

- (void)draggableView:(CHDraggableView *)view didMoveToPoint:(CGPoint)point
{
    CGRect viewDragRect = [[self dismissAreaView] convertRect:view.frame fromView:self.window];
    
    //check if point is inside button X
    UIButton *buttonX = (UIButton *)[[self dismissAreaView]viewWithTag:kDismissViewButtonXTag];
    if (buttonX) {
        BOOL rectInside = CGRectIntersectsRect(buttonX.frame, viewDragRect);
        
        //backup state before change to dismiss
        if (_state != CHInteractionStateReadyToDismiss) {
            _previousState = _state;
        }
        
        if (rectInside) {
            //animate button
            if (_state != CHInteractionStateReadyToDismiss) {
                
                [UIView animateWithDuration:0.1f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    CGRect zoomRect = CGRectInset(_buttonXFrame, -kDismissViewHeightZoomInsect - kDismissViewHeightZoomInsectBounce, -kDismissViewHeightZoomInsect - kDismissViewHeightZoomInsectBounce);
                    buttonX.frame = zoomRect;
                }completion:^(BOOL finished){
                    if (finished) {
                        [UIView animateWithDuration:0.1f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
                            CGRect zoomRect = CGRectInset(_buttonXFrame, -kDismissViewHeightZoomInsect, -kDismissViewHeightZoomInsect);
                            buttonX.frame = zoomRect;
                        }completion:^(BOOL finished){
                            
                        }];
                    }

                }];
                
            }
            
            _state = CHInteractionStateReadyToDismiss;
            
        } else {
            if (_state != _previousState) {
                _state = _previousState;
                
                //remove all animation
                [buttonX.layer removeAllAnimations];
                
                [UIView animateWithDuration:0.1f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    //animate button back to previous state
                    buttonX.frame = _buttonXFrame;

                }completion:^(BOOL finished){
                   
                }];
                
            
            }
            
            

        }
        
    }
    
    if (_state == CHInteractionStateConversation) {
        if (_presentedNavigationController) {
            [self _dismissPresentedNavigationController];    
        }
    }
    
    if ([[self dismissAreaView] superview] == nil) {
        [self _showDismissViewArea];
    }
    
    
}

- (void)draggableViewReleased:(CHDraggableView *)view
{
    [self _dismissDismissViewArea];
    
    if (_state == CHInteractionStateNormal) {
        [self _animateViewToEdges:view];
    } else if(_state == CHInteractionStateConversation) {
        [self _animateViewToConversationArea:view];
        [self _presentViewControllerForDraggableView:view];
    } else if (_state == CHInteractionStateReadyToDismiss) {
        [self _dismissDragView:view];
    }
    
}

- (void)draggableViewTouched:(CHDraggableView *)view
{
    if (_state == CHInteractionStateNormal) {
        _state = CHInteractionStateConversation;
        [self _animateViewToConversationArea:view];
        
        [self _presentViewControllerForDraggableView:view];
    } else if(_state == CHInteractionStateConversation) {
        _state = CHInteractionStateNormal;
        NSValue *knownEdgePoint = [_edgePointDictionary objectForKey:@(view.tag)];
        if (knownEdgePoint) {
            [self _animateView:view toEdgePoint:[knownEdgePoint CGPointValue]];
        } else {
            [self _animateViewToEdges:view];
        }
        [self _dismissPresentedNavigationController];
    }
}

#pragma mark Dragging Helper

- (void)_animateViewToEdges:(CHDraggableView *)view
{
    CGPoint destinationPoint = [self _destinationPointForReleasePoint:view.center];    
    [self _animateView:view toEdgePoint:destinationPoint];
}

- (void)_animateView:(CHDraggableView *)view toEdgePoint:(CGPoint)point
{
    [_edgePointDictionary setObject:[NSValue valueWithCGPoint:point] forKey:@(view.tag)];
    [view snapViewCenterToPoint:point edge:[self _destinationEdgeForReleasePointInCurrentState:view.center]];
}

- (void)_animateViewToConversationArea:(CHDraggableView *)view
{
    CGRect conversationArea = [self _conversationArea];
    CGPoint center = CGPointMake(CGRectGetMidX(conversationArea), CGRectGetMidY(conversationArea));
    [view snapViewCenterToPoint:center edge:[self _destinationEdgeForReleasePointInCurrentState:view.center]];
}

#pragma mark - View Controller Handling

- (CGRect)_navigationControllerFrame
{
    CGRect slice;
    CGRect remainder;
    CGRectDivide([self.window.screen applicationFrame], &slice, &remainder, CGRectGetMaxY([self _conversationArea]), CGRectMinYEdge);
    return remainder;
}


- (CGRect)_navigationControllerHiddenFrame
{
    return CGRectMake(CGRectGetMidX([self _conversationArea]), CGRectGetMaxY([self _conversationArea]), 0, 0);
}

- (CGRect)_dismissAreaFrame
{
    
    CGRect windowFrame = [self.window.screen applicationFrame];
    CGRect outFrame = CGRectMake(0.0f, CGRectGetMaxY(windowFrame) - kDismissViewHeight, windowFrame.size.width, kDismissViewHeight);
    
    NSLog(@"outFrame: %@", NSStringFromCGRect(outFrame));
    return outFrame;
    
}

- (CGRect)_dismissAreaHiddenFrame
{
    CGRect windowFrame = [self.window.screen applicationFrame];
    return CGRectMake(0.0f, CGRectGetMaxY(windowFrame), windowFrame.size.width, kDismissViewHeight);

}

- (CGRect)_dismissDragHiddenFrame
{
    CGRect windowFrame = [self.window.screen applicationFrame];
    return CGRectMake(CGRectGetMidX(windowFrame), CGRectGetMaxY(windowFrame), windowFrame.size.width, kDismissViewHeight);
    
}

- (void)_presentViewControllerForDraggableView:(CHDraggableView *)draggableView
{
    UIViewController *viewController = [_delegate draggingCoordinator:self viewControllerForDraggableView:draggableView];
    
    _presentedNavigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    _presentedNavigationController.view.layer.cornerRadius = 3;
    _presentedNavigationController.view.layer.masksToBounds = YES;
    _presentedNavigationController.view.layer.anchorPoint = CGPointMake(0.5f, 0);
    _presentedNavigationController.view.frame = [self _navigationControllerFrame];
    _presentedNavigationController.view.transform = CGAffineTransformMakeScale(0, 0);
    
    [self.window insertSubview:_presentedNavigationController.view belowSubview:draggableView];
    
    
    [self _unhidePresentedNavigationControllerCompletion:^{}];
}

- (void)_dismissPresentedNavigationController
{
    UINavigationController *reference = _presentedNavigationController;
    [self _hidePresentedNavigationControllerCompletion:^{
        [reference.view removeFromSuperview];
    }];
    _presentedNavigationController = nil;
}

- (UIView *)dismissAreaView;
{
    if (_dismissAreaView == nil) {
        CGRect dissmissFrame = [self _dismissAreaHiddenFrame];
        _dismissAreaView = [[UIView alloc]initWithFrame:dissmissFrame];
        _dismissAreaView.layer.masksToBounds = NO;
        
        //add label
        CGRect frameLabel = CGRectMake(0.0f, CGRectGetHeight(dissmissFrame) - kDismissViewLabelHeight, dissmissFrame.size.width, kDismissViewLabelHeight);
        UILabel *lblDismiss = [[UILabel alloc]initWithFrame:frameLabel];
        lblDismiss.backgroundColor = [UIColor clearColor];
        lblDismiss.textAlignment = ALIGN_CENTER;
        lblDismiss.text = @"Drag down to close";
        lblDismiss.textColor = [UIColor whiteColor];
        lblDismiss.font = [UIFont boldSystemFontOfSize:kDismissViewLabelFontSize];
        lblDismiss.shadowColor = [UIColor darkGrayColor];
        lblDismiss.shadowOffset = CGSizeMake(1.0f, 1.0f);
        
        [_dismissAreaView addSubview:lblDismiss];
        
        //add button
        UIImage *imageX = [UIImage imageNamed:@"x_button.png"];
        UIImage *imageCircle = [UIImage imageNamed:@"circle.png"];

        UIButton *buttonX = [UIButton buttonWithType:UIButtonTypeCustom];
        CGFloat newY = (CGRectGetHeight(dissmissFrame) - kDismissButtonHeight)/2.0;
        newY = frameLabel.origin.y - kDismissButtonHeight - kDismissViewLabelButtonSpace;
        buttonX.frame = CGRectMake(CGRectGetMidX(dissmissFrame) - kDismissButtonHeight/2.0, newY, kDismissButtonHeight, kDismissButtonHeight);
        buttonX.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        buttonX.userInteractionEnabled = NO;
        [buttonX setImage:imageX forState:UIControlStateNormal];
        [buttonX setBackgroundImage:imageCircle forState:UIControlStateNormal];
        buttonX.clipsToBounds = NO;
        buttonX.tag = kDismissViewButtonXTag;
        
        //zoom button
        _buttonXFrame = buttonX.frame;

        [_dismissAreaView addSubview:buttonX];
        
               
    }
    
    return _dismissAreaView;

}

- (void)_showDismissViewArea
{
    NSLog(@"_showDismissViewArea");
    if ([[self dismissAreaView] superview] == nil) {
        UIView *subView = [[self.window subviews]objectAtIndex:0];
        [self.window insertSubview:[self dismissAreaView] aboveSubview:subView];
    }
    
    [self dismissAreaView].alpha = 1.0f;
    
    [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        CGRect firstFrameAnimation = [self _dismissAreaFrame];
        firstFrameAnimation.origin.y -= kDismissViewAnimationBounce;
        [self dismissAreaView].frame = firstFrameAnimation;
        
    }completion:^(BOOL finished){
        if (finished) {
            [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
                [self dismissAreaView].frame = [self _dismissAreaFrame];
                
            }completion:^(BOOL finished){
                if (finished) {
                    
                }
            }];
        }
    }];
    
}

- (void)_dismissDismissViewArea
{
    [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self dismissAreaView].frame = [self _dismissAreaHiddenFrame];
    }completion:^(BOOL finished){

        if (finished) {
            [self dismissAreaView].alpha = 0.0f;
            [[self dismissAreaView] removeFromSuperview];
        }
    }];
    
}

- (void)_dismissDragView:(CHDraggableView *)dragView
{
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        CGRect frameDragView = dragView.frame;
        
        CGRect windowFrame = [self.window.screen applicationFrame];
        frameDragView.origin.y = CGRectGetMaxY(windowFrame);
        dragView.frame = frameDragView;
        
    }completion:^(BOOL finished){
        
        if (finished) {
            if (_delegate && [_delegate respondsToSelector:@selector(draggingCoordinator:didDismissDraggableView:)]) {
                [_delegate draggingCoordinator:self didDismissDraggableView:dragView];
            }
            
            dragView.alpha = 0.0f;
            [dragView removeFromSuperview];
            
        }
    }];
    
}



- (void)_unhidePresentedNavigationControllerCompletion:(void(^)())completionBlock
{
    CGAffineTransform transformStep1 = CGAffineTransformMakeScale(1.1f, 1.1f);
    CGAffineTransform transformStep2 = CGAffineTransformMakeScale(1, 1);
    
    _backgroundView = [[UIView alloc] initWithFrame:[self.window bounds]];
    _backgroundView.backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.5f];
    _backgroundView.alpha = 0.0f;
    [self.window insertSubview:_backgroundView belowSubview:_presentedNavigationController.view];
    
    //remove previous animation
    [_presentedNavigationController.view.layer removeAllAnimations];
    [_backgroundView.layer removeAllAnimations];
    
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        _presentedNavigationController.view.layer.affineTransform = transformStep1;
        _backgroundView.alpha = 1.0f;
        NSLog(@"_backgroundView.alpha = 1.0f;");
    }completion:^(BOOL finished){
        if (finished) {
            [UIView animateWithDuration:0.3f animations:^{
                _presentedNavigationController.view.layer.affineTransform = transformStep2;
            }];
        }
    }];
}

- (void)_hidePresentedNavigationControllerCompletion:(void(^)())completionBlock
{
    //remove previous animation
//    [_presentedNavigationController.view.layer removeAllAnimations];
//    [_backgroundView.layer removeAllAnimations];

    [UIView animateWithDuration:0.3f delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        _presentedNavigationController.view.transform = CGAffineTransformMakeScale(0, 0);
        _presentedNavigationController.view.alpha = 0.0f;
        _backgroundView.alpha = 0.0f;
        NSLog(@"_backgroundView.alpha = 0.0f;");
        
    } completion:^(BOOL finished){
        if (finished) {
            [_backgroundView removeFromSuperview];
            _backgroundView = nil;
            completionBlock();
        }
    }];
}

@end
