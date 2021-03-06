//
//  ZLShowBigImgViewController.h
//  多选相册照片
//
//  Created by long on 15/11/25.
//  Copyright © 2015年 long. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@class ZLPhotoModel;

@interface ZLShowBigImgViewController : UIViewController

@property (nonatomic, strong) NSArray<ZLPhotoModel *> *models;

@property (nonatomic, assign) NSInteger selectIndex; //选中的图片下标

//@property (nonatomic, copy) void (^btnBackBlock)(NSArray<ZLPhotoModel *> *selectedModels, BOOL isOriginal, NSArray<PHAsset *> *assets);

@property (nonatomic, copy) void (^btnBackBlock)(NSArray<ZLPhotoModel *> *selectedModels, BOOL isOriginal,NSArray<UIImage *> *images, NSArray<PHAsset *> *assets);

//点击选择后的图片预览数组，预览相册图片时为 UIImage，预览网络图片时候为UIImage/NSUrl
@property (nonatomic, strong) NSMutableArray *arrSelPhotos;

//预览相册图片回调
@property (nonatomic, copy) void (^btnDonePreviewBlock)(NSArray<UIImage *> *, NSArray<PHAsset *> *, BOOL isOriginal);

//预览网络图片回调
@property (nonatomic, copy) void (^previewNetImageBlock)(NSArray *photos);

@end
