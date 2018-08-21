//
//  ZLPhotoActionSheet.m
//  多选相册照片
//
//  Created by long on 15/11/25.
//  Copyright © 2015年 long. All rights reserved.
//

#import "ZLPhotoActionSheet.h"
#import <Photos/Photos.h>
#import "ZLCollectionCell.h"
#import "ZLPhotoModel.h"
#import "ZLPhotoManager.h"
#import "ZLPhotoBrowser.h"
#import "ZLShowBigImgViewController.h"
#import "ZLThumbnailViewController.h"
#import "ZLNoAuthorityViewController.h"
#import "ToastUtils.h"
#import "ZLEditViewController.h"

#define kBaseViewHeight (self.maxPreviewCount ? 309 : 142)

double const ScalePhotoWidth = 1000;

@interface ZLPhotoActionSheet () <UICollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPhotoLibraryChangeObserver>

@property (weak, nonatomic) IBOutlet UIView *topBackView;
@property (weak, nonatomic) IBOutlet UIButton *btnCamera;
@property (weak, nonatomic) IBOutlet UIButton *btnAblum;
@property (weak, nonatomic) IBOutlet UIButton *btnCancel;
@property (weak, nonatomic) IBOutlet UIView *baseView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *verColHeight;


@property (nonatomic, assign) BOOL animate;
@property (nonatomic, assign) BOOL preview;

@property (nonatomic, strong) NSMutableArray<ZLPhotoModel *> *arrDataSources;

@property (nonatomic, copy) NSMutableArray<ZLPhotoModel *> *arrSelectedModels;

@property (nonatomic, assign) UIStatusBarStyle previousStatusBarStyle;
@property (nonatomic, assign) BOOL senderTabBarIsShow;
@property (nonatomic, strong) UILabel *placeholderLabel;

@end

@implementation ZLPhotoActionSheet

- (void)dealloc
{
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
//    NSLog(@"---- %s", __FUNCTION__);
}

- (NSMutableArray<ZLPhotoModel *> *)arrDataSources
{
    if (!_arrDataSources) {
        _arrDataSources = [NSMutableArray array];
    }
    return _arrDataSources;
}

- (NSMutableArray<ZLPhotoModel *> *)arrSelectedModels
{
    if (!_arrSelectedModels) {
        _arrSelectedModels = [NSMutableArray array];
    }
    return _arrSelectedModels;
}

- (UILabel *)placeholderLabel
{
    if (!_placeholderLabel) {
        _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kViewWidth, 100)];
        _placeholderLabel.text = GetLocalLanguageTextValue(ZLPhotoBrowserNoPhotoText);
        _placeholderLabel.textAlignment = NSTextAlignmentCenter;
        _placeholderLabel.textColor = [UIColor darkGrayColor];
        _placeholderLabel.font = [UIFont systemFontOfSize:15];
        _placeholderLabel.center = self.collectionView.center;
        [self.collectionView addSubview:_placeholderLabel];
        _placeholderLabel.hidden = YES;
    }
    return _placeholderLabel;
}

- (void)setArrSelectedAssets:(NSMutableArray<PHAsset *> *)arrSelectedAssets
{
    _arrSelectedAssets = arrSelectedAssets;
    [self.arrSelectedModels removeAllObjects];
    for (PHAsset *asset in arrSelectedAssets) {
        ZLPhotoModel *model = [ZLPhotoModel modelWithAsset:asset type:[ZLPhotoManager transformAssetType:asset] duration:nil];
        model.isSelected = YES;
        [self.arrSelectedModels addObject:model];
    }
}

- (void)setAllowSelectLivePhoto:(BOOL)allowSelectLivePhoto
{
    _allowSelectLivePhoto = allowSelectLivePhoto;
    if ([UIDevice currentDevice].systemVersion.floatValue < 9.0) {
        _allowSelectLivePhoto = NO;
    }
}

- (instancetype)init
{
    self = [[kZLPhotoBrowserBundle loadNibNamed:@"ZLPhotoActionSheet" owner:self options:nil] lastObject];
    if (self = [super init]) {
        
        self.backgroundColor = GrayColorEight;
        ViewRadius(_topBackView, 5);
        ViewRadius(_btnCancel, 5);
        
        
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        layout.minimumInteritemSpacing = 3;
        layout.sectionInset = UIEdgeInsetsMake(0, 5, 0, 5);
        
        self.collectionView.collectionViewLayout = layout;
        self.collectionView.backgroundColor = [UIColor clearColor];
        [self.collectionView registerClass:NSClassFromString(@"ZLCollectionCell") forCellWithReuseIdentifier:@"ZLCollectionCell"];
        
        self.maxSelectCount = 10;
        self.maxPreviewCount = 20;
        self.maxVideoDuration = 120;
        self.cellCornerRadio = .0;
        self.allowsEditing = NO;
        self.allowSelectImage = YES;
        self.allowSelectVideo = YES;
        self.allowSelectGif = YES;
        self.allowSelectLivePhoto = NO;
        self.allowTakePhotoInLibrary = YES;
        self.allowForceTouch = YES;
        self.allowEditImage = YES;
        self.editAfterSelectThumbnailImage = NO;
        self.allowMixSelect = YES;
        self.showCaptureImageOnTakePhotoBtn = YES;
        self.sortAscending = YES;
        self.showSelectBtn = NO;
        self.showSelectedMask = NO;
        self.selectedMaskColor = [UIColor blackColor];
        
        if (![self judgeIsHavePhotoAblumAuthority]) {
            //注册实施监听相册变化
            [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
        }
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self.btnCamera setTitle:GetLocalLanguageTextValue(ZLPhotoBrowserCameraText) forState:UIControlStateNormal];
    [self.btnAblum setTitle:GetLocalLanguageTextValue(ZLPhotoBrowserAblumText) forState:UIControlStateNormal];
    [self.btnCancel setTitle:GetLocalLanguageTextValue(ZLPhotoBrowserCancelText) forState:UIControlStateNormal];
    [self resetSubViewState];
}

//相册变化回调
- (void)photoLibraryDidChange:(PHChange *)changeInstance
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (self.preview) {
            [self loadPhotoFromAlbum];
            [self show];
        } else {
            [self btnPhotoLibrary_Click:nil];
        }
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    });
}

- (void)showPreviewAnimated:(BOOL)animate sender:(UIViewController *)sender
{
    self.sender = sender;
    [self showPreviewAnimated:animate];
}

- (void)showPreviewAnimated:(BOOL)animate
{
    [self showPreview:YES animate:animate];
}

- (void)showPhotoLibraryWithSender:(UIViewController *)sender
{
    self.sender = sender;
    [self showPhotoLibrary];
}

- (void)showPhotoLibrary
{
    [self showPreview:NO animate:NO];
}

- (void)showPreview:(BOOL)preview animate:(BOOL)animate
{
    if (!self.allowSelectImage && self.arrSelectedModels.count) {
        [self.arrSelectedAssets removeAllObjects];
        [self.arrSelectedModels removeAllObjects];
    }
    if (self.maxSelectCount > 1) {
        self.showSelectBtn = YES;
    }
    self.animate = animate;
    self.preview = preview;
    self.previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
    
    [ZLPhotoManager setSortAscending:self.sortAscending];
    
    if (!self.maxPreviewCount) {
        self.verColHeight.constant = .0;
    }
    
    
//    if (preview) {
//        [self show];
//    } else {
//        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
//        if (status == PHAuthorizationStatusAuthorized) {
//            [self.sender.view addSubview:self];
//            [self btnPhotoLibrary_Click:nil];
//        } else if (status == PHAuthorizationStatusRestricted ||
//                   status == PHAuthorizationStatusDenied) {
//            [self showNoAuthorityVC];
//        }
//    }

    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    
    if (status == PHAuthorizationStatusRestricted ||
        status == PHAuthorizationStatusDenied) {
        [self showNoAuthorityVC];
    } else if (status == PHAuthorizationStatusNotDetermined) {
//        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
//            
//        }];
        
        [self.sender.view addSubview:self];
    }
    
    if (preview) {
        if (status == PHAuthorizationStatusAuthorized) {
            [self loadPhotoFromAlbum];
            [self show];
        } else if (status == PHAuthorizationStatusRestricted ||
                   status == PHAuthorizationStatusDenied) {
            [self showNoAuthorityVC];
        }
    } else {
        if (status == PHAuthorizationStatusAuthorized) {
            [self.sender.view addSubview:self];
            [self btnPhotoLibrary_Click:nil];
        } else if (status == PHAuthorizationStatusRestricted ||
                   status == PHAuthorizationStatusDenied) {
            [self showNoAuthorityVC];
        }
    }
    
}

- (void)previewSelectedPhotos:(NSArray<UIImage *> *)photos assets:(NSArray<PHAsset *> *)assets index:(NSInteger)index
{
    self.arrSelectedAssets = [NSMutableArray arrayWithArray:assets];
    ZLShowBigImgViewController *svc = [self pushBigImageToPreview:photos index:index];
    WeakSelf
    __weak typeof(svc.navigationController) weakNav = svc.navigationController;
    [svc setBtnDonePreviewBlock:^(NSArray<UIImage *> *photos, NSArray<PHAsset *> *assets, BOOL isOriginal) {
        weakSelf.arrSelectedAssets = assets.mutableCopy;
        __strong typeof(weakNav) strongNav = weakNav;
        if (weakSelf.selectImageBlock) {
            weakSelf.selectImageBlock(photos, assets, isOriginal);
        }
        [strongNav dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [svc setBtnBackBlock:^(NSArray<ZLPhotoModel *> *selectedModels, BOOL isOriginal,NSArray<UIImage *> *images, NSArray<PHAsset *> *assets){
        if (weakSelf.selectImageBlock) {
            weakSelf.selectImageBlock(images, assets, isOriginal);
        }
    }];
}

- (void)previewPhotos:(NSArray *)photos index:(NSInteger)index complete:(nonnull void (^)(NSArray * _Nonnull))complete
{
    [self.arrSelectedModels removeAllObjects];
    for (id obj in photos) {
        ZLPhotoModel *model = [[ZLPhotoModel alloc] init];
        if ([obj isKindOfClass:UIImage.class]) {
            model.image = obj;
        } else if ([obj isKindOfClass:NSURL.class]) {
            model.url = obj;
        }
        model.type = ZLAssetMediaTypeNetImage;
        model.isSelected = YES;
        [self.arrSelectedModels addObject:model];
    }
    ZLShowBigImgViewController *svc = [self pushBigImageToPreview:photos index:index];
    __weak typeof(svc.navigationController) weakNav = svc.navigationController;
    [svc setPreviewNetImageBlock:^(NSArray *photos) {
        __strong typeof(weakNav) strongNav = weakNav;
        if (complete) complete(photos);
        [strongNav dismissViewControllerAnimated:YES completion:nil];
    }];
}

#pragma mark - 判断软件是否有相册、相机访问权限
- (BOOL)judgeIsHavePhotoAblumAuthority
{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusAuthorized) {
        return YES;
    }
    return NO;
}

- (BOOL)judgeIsHaveCameraAuthority
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusRestricted ||
        status == AVAuthorizationStatusDenied) {
        return NO;
    }
    return YES;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:GetLocalLanguageTextValue(ZLPhotoBrowserOKText) style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:action];
    [self.sender presentViewController:alert animated:YES completion:nil];
}

- (void)loadPhotoFromAlbum
{
    [self.arrDataSources removeAllObjects];
    
    [self.arrDataSources addObjectsFromArray:[ZLPhotoManager getAllAssetInPhotoAlbumWithAscending:NO limitCount:self.maxPreviewCount allowSelectVideo:self.allowSelectVideo allowSelectImage:self.allowSelectImage allowSelectGif:self.allowSelectGif allowSelectLivePhoto:self.allowSelectLivePhoto]];
    [ZLPhotoManager markSelcectModelInArr:self.arrDataSources selArr:self.arrSelectedModels];
    [self.collectionView reloadData];
}

#pragma mark - 显示隐藏视图及相关动画
- (void)resetSubViewState
{
    self.hidden = ![self judgeIsHavePhotoAblumAuthority] || !self.preview;
    [self changeCancelBtnTitle];
    [self.collectionView setContentOffset:CGPointZero];
}

- (void)show
{
    self.frame = self.sender.view.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (!self.superview) {
        //[nowAppDelegate().window addSubview:self];//使用此方法，导致拍照时取消按钮和重新拍照按钮点击失效
        
        self.backgroundColor = [UIColor clearColor];//颜色渐变效果
        [self.sender.view addSubview:self];
    }
    if (self.sender.tabBarController.tabBar.hidden == NO) {
        self.senderTabBarIsShow = YES;
        self.sender.tabBarController.tabBar.hidden = YES;
    }
    
    if (self.animate) {
        __block CGRect frame = self.baseView.frame;
        frame.origin.y += kBaseViewHeight;
        self.baseView.frame = frame;
        [UIView animateWithDuration:0.2 animations:^{
            self.backgroundColor = GrayColorEight;//颜色渐变效果
            frame.origin.y -= kBaseViewHeight;
            self.baseView.frame = frame;
        } completion:nil];
    }
}

- (void)hide
{
    if (self.animate) {
        __block CGRect frame = self.baseView.frame;
        //frame.origin.y += kBaseViewHeight;
        frame.origin.y += kBaseViewHeight + 30;
        [UIView animateWithDuration:0.2 animations:^{
            self.baseView.frame = frame;
            self.backgroundColor = [UIColor clearColor];//颜色渐变效果
        } completion:^(BOOL finished) {
            
            self.hidden = YES;
            [self removeFromSuperview];
        }];
    } else {
        self.hidden = YES;
        [self removeFromSuperview];
    }
    if (self.senderTabBarIsShow) {
        self.sender.tabBarController.tabBar.hidden = NO;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self hide];
}

#pragma mark - UIButton Action
- (IBAction)btnCamera_Click:(id)sender
{
    
    if (![self judgeIsHaveCameraAuthority]) {
        NSString *message = [NSString stringWithFormat:GetLocalLanguageTextValue(ZLPhotoBrowserNoCameraAuthorityText), [[NSBundle mainBundle].infoDictionary valueForKey:(__bridge NSString *)kCFBundleNameKey]];
        [self showAlertWithTitle:nil message:message];
        [self hide];
        return;
    }
    //拍照
    if ([UIImagePickerController isSourceTypeAvailable:
         UIImagePickerControllerSourceTypeCamera])
    {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.allowsEditing = NO;
        picker.videoQuality = UIImagePickerControllerQualityTypeLow;
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self.sender presentViewController:picker animated:YES completion:nil];
    }
}

- (IBAction)btnPhotoLibrary_Click:(id)sender
{
//    if (![self judgeIsHavePhotoAblumAuthority]) {
//        [self showNoAuthorityVC];
//    } else {
//        self.animate = NO;
//        [self pushThumbnailViewController];
//    }
    self.animate = NO;
    [self pushThumbnailViewController];
}

#pragma mark - 聊天消息界面选择照片发送照片入口
-(void)customSlectedPhoto
{
    if (!self.allowSelectImage && self.arrSelectedModels.count) {
        [self.arrSelectedAssets removeAllObjects];
        [self.arrSelectedModels removeAllObjects];
    }
    if (self.maxSelectCount > 1) {
        self.showSelectBtn = YES;
    }
    self.animate = YES;
    self.preview = YES;
    self.previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
    
    [ZLPhotoManager setSortAscending:self.sortAscending];
    
    if (!self.maxPreviewCount) {
        self.verColHeight.constant = .0;
    }
    
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusRestricted ||
        status == PHAuthorizationStatusDenied) {
        [self showNoAuthorityVC];
    } else if (status == PHAuthorizationStatusNotDetermined) {
        //[self.sender.view addSubview:self];
    }
    if (_preview) {
        if (status == PHAuthorizationStatusAuthorized) {
            [self loadPhotoFromAlbum];
            //[self show];
        } else if (status == PHAuthorizationStatusRestricted ||
                   status == PHAuthorizationStatusDenied) {
            [self showNoAuthorityVC];
        }
    } else {
        if (status == PHAuthorizationStatusAuthorized) {
            //[self.sender.view addSubview:self];
            [self btnPhotoLibrary_Click:nil];
        } else if (status == PHAuthorizationStatusRestricted ||
                   status == PHAuthorizationStatusDenied) {
            [self showNoAuthorityVC];
        }
    }
    
    //相册按钮点击事件
    if (![self judgeIsHavePhotoAblumAuthority]) {
        [self showNoAuthorityVC];
    } else {
        self.animate = NO;
        [self pushThumbnailViewController];
    }
}

- (IBAction)btnCancel_Click:(id)sender
{
//    if (self.arrSelectedModels.count) {
//        [self requestSelPhotos:nil];
//        return;
//    }
    [self hide];
}

- (void)changeCancelBtnTitle
{
//    if (self.arrSelectedModels.count > 0) {
//        [self.btnCancel setTitle:[NSString stringWithFormat:@"%@(%ld)", GetLocalLanguageTextValue(ZLPhotoBrowserDoneText), self.arrSelectedModels.count] forState:UIControlStateNormal];
//        [self.btnCancel setTitleColor:kDoneButton_bgColor forState:UIControlStateNormal];
//    } else {
//        [self.btnCancel setTitle:GetLocalLanguageTextValue(ZLPhotoBrowserCancelText) forState:UIControlStateNormal];
//        [self.btnCancel setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
//    }
}

#pragma mark - 请求所选择图片、回调
- (void)requestSelPhotos:(UIViewController *)vc
{
    ZLProgressHUD *hud = [[ZLProgressHUD alloc] init];
    [hud show];
    
    NSMutableArray *photos = [NSMutableArray arrayWithCapacity:self.arrSelectedModels.count];
    NSMutableArray *assets = [NSMutableArray arrayWithCapacity:self.arrSelectedModels.count];
    
        for (int i = 0; i < self.arrSelectedModels.count; i++) {
            [photos addObject:@""];
            [assets addObject:@""];
        }
        
        WeakSelf
        for (int i = 0; i < self.arrSelectedModels.count; i++) {
            ZLPhotoModel *model = self.arrSelectedModels[i];
            [ZLPhotoManager requestSelectedImageForAsset:model isOriginal:self.isSelectOriginalPhoto allowSelectGif:self.allowSelectGif completion:^(UIImage *image, NSDictionary *info) {
                if ([[info objectForKey:PHImageResultIsDegradedKey] boolValue]) return;
                
                if (image) {
                    [photos replaceObjectAtIndex:i withObject:[weakSelf scaleImage:image]];
                    [assets replaceObjectAtIndex:i withObject:model.asset];
                }
                
                for (id obj in photos) {
                    if ([obj isKindOfClass:[NSString class]]) return;
                }
                
                [hud hide];
                
                if (weakSelf.selectImageBlock) {
                    weakSelf.selectImageBlock(photos, assets, weakSelf.isSelectOriginalPhoto);
                }
                [weakSelf hide];
                [vc dismissViewControllerAnimated:YES completion:nil];
            }];
   }
    
}

/**
 * @brief 这里对拿到的图片进行缩放，不然原图直接返回的话会造成内存暴涨
 */
- (UIImage *)scaleImage:(UIImage *)image
{
    CGSize size = CGSizeMake(ScalePhotoWidth, ScalePhotoWidth * image.size.height / image.size.width);
    if (image.size.width < size.width
        ) {
        return image;
    }
    UIGraphicsBeginImageContext(size);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

#pragma mark - UICollectionDataSource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.arrDataSources.count == 0) {
        self.placeholderLabel.hidden = NO;
    } else {
        self.placeholderLabel.hidden = YES;
    }
    return self.arrDataSources.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ZLCollectionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ZLCollectionCell" forIndexPath:indexPath];
    
    ZLPhotoModel *model = self.arrDataSources[indexPath.row];
    
    WeakSelf
    __weak typeof(cell) weakCell = cell;
    cell.selectedBlock = ^(BOOL selected) {
        
        __strong typeof(weakCell) strongCell = weakCell;
        if (!selected) {
            //选中
            if (weakSelf.arrSelectedModels.count >= weakSelf.maxSelectCount) {
                ShowToastLong(GetLocalLanguageTextValue(ZLPhotoBrowserMaxSelectCountText), weakSelf.maxSelectCount);
                return;
            }
            if (weakSelf.arrSelectedModels.count > 0) {
                ZLPhotoModel *sm = weakSelf.arrSelectedModels.firstObject;
                if (!weakSelf.allowMixSelect &&
                    ((model.type < ZLAssetMediaTypeVideo && sm.type == ZLAssetMediaTypeVideo) || (model.type == ZLAssetMediaTypeVideo && sm.type < ZLAssetMediaTypeVideo))) {
                    ShowToastLong(@"%@", GetLocalLanguageTextValue(ZLPhotoBrowserCannotSelectVideo));
                    return;
                }
            }
            if (![ZLPhotoManager judgeAssetisInLocalAblum:model.asset]) {
                ShowToastLong(@"%@", GetLocalLanguageTextValue(ZLPhotoBrowseriCloudPhotoText));
                return;
            }
            if (model.type == ZLAssetMediaTypeVideo && GetDuration(model.duration) > weakSelf.maxVideoDuration) {
                ShowToastLong(GetLocalLanguageTextValue(ZLPhotoBrowserMaxVideoDurationText), weakSelf.maxVideoDuration);
                return;
            }
            
            model.isSelected = YES;
            [weakSelf.arrSelectedModels addObject:model];
            strongCell.btnSelect.selected = YES;
        } else {
            strongCell.btnSelect.selected = NO;
            model.isSelected = NO;
            for (ZLPhotoModel *m in weakSelf.arrSelectedModels) {
                if ([m.asset.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                    [weakSelf.arrSelectedModels removeObject:m];
                    break;
                }
            }
        }
        
        if (weakSelf.showSelectedMask) {
            strongCell.topView.hidden = !model.isSelected;
        }
        //[strongSelf changeCancelBtnTitle];
    };
    
    cell.allSelectGif = self.allowSelectGif;
    cell.allSelectLivePhoto = self.allowSelectLivePhoto;
    cell.showSelectBtn = self.showSelectBtn;
    cell.cornerRadio = self.cellCornerRadio;
    cell.showMask = self.showSelectedMask;
    cell.maskColor = self.selectedMaskColor;
    cell.model = model;
    
    return cell;
}

#pragma mark - UICollectionViewDelegate
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ZLPhotoModel *model = self.arrDataSources[indexPath.row];
    return [self getSizeWithAsset:model.asset];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    ZLPhotoModel *model = self.arrDataSources[indexPath.row];
    
    if (self.editAfterSelectThumbnailImage &&
        self.allowEditImage &&
        self.maxSelectCount == 1) {
        [self pushEditVCWithModel:model];
        return;
    }
    
    if (self.arrSelectedModels.count > 0) {
        ZLPhotoModel *sm = self.arrSelectedModels.firstObject;
        if (!self.allowMixSelect &&
            ((model.type < ZLAssetMediaTypeVideo && sm.type == ZLAssetMediaTypeVideo) || (model.type == ZLAssetMediaTypeVideo && sm.type < ZLAssetMediaTypeVideo))) {
            ShowToastLong(@"%@", GetLocalLanguageTextValue(ZLPhotoBrowserCannotSelectVideo));
            return;
        }
    }
    
    BOOL allowSelImage = !(model.type==ZLAssetMediaTypeVideo)?YES:self.allowMixSelect;
    BOOL allowSelVideo = model.type==ZLAssetMediaTypeVideo?YES:self.allowMixSelect;
    
    NSArray *arr = [ZLPhotoManager getAllAssetInPhotoAlbumWithAscending:self.sortAscending limitCount:NSIntegerMax allowSelectVideo:allowSelVideo allowSelectImage:allowSelImage allowSelectGif:self.allowSelectGif allowSelectLivePhoto:self.allowSelectLivePhoto];
    
    NSMutableArray *selIdentifiers = [NSMutableArray array];
    for (ZLPhotoModel *m in self.arrSelectedModels) {
        [selIdentifiers addObject:m.asset.localIdentifier];
    }
    
    int i = 0;
    BOOL isFind = NO;
    for (ZLPhotoModel *m in arr) {
        if ([m.asset.localIdentifier isEqualToString:model.asset.localIdentifier]) {
            isFind = YES;
        }
        if ([selIdentifiers containsObject:m.asset.localIdentifier]) {
            m.isSelected = YES;
        }
        if (!isFind) {
            i++;
        }
    }
    
    [self pushBigImageViewControllerWithModels:arr index:i];
}

#pragma mark - 显示无权限视图
- (void)showNoAuthorityVC
{
    //无相册访问权限
    ZLNoAuthorityViewController *nvc = [[ZLNoAuthorityViewController alloc] init];
    [self.sender showDetailViewController:[self getImageNavWithRootVC:nvc] sender:nil];
}

- (ZLImageNavigationController *)getImageNavWithRootVC:(UIViewController *)rootVC
{
    ZLImageNavigationController *nav = [[ZLImageNavigationController alloc] initWithRootViewController:rootVC];
    
    WeakSelf
    __weak typeof(ZLImageNavigationController *) weakNav = nav;
    [nav setCallSelectImageBlock:^{
        weakSelf.isSelectOriginalPhoto = weakNav.isSelectOriginalPhoto;
        [weakSelf.arrSelectedModels removeAllObjects];
        [weakSelf.arrSelectedModels addObjectsFromArray:weakNav.arrSelectedModels];
        [weakSelf requestSelPhotos:weakNav];
    }];
    
    [nav setCallSelectClipImageBlock:^(UIImage *image, PHAsset *asset){
        if (weakSelf.selectImageBlock) {
            weakSelf.selectImageBlock(@[image], @[asset], weakSelf.isSelectOriginalPhoto);
        }
        [weakSelf hide];
        [weakNav dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [nav setCancelBlock:^{
        [weakSelf hide];
    }];

    nav.previousStatusBarStyle = self.previousStatusBarStyle;
    nav.maxSelectCount = self.maxSelectCount;
    nav.maxVideoDuration = self.maxVideoDuration;
    nav.cellCornerRadio = self.cellCornerRadio;
    nav.allowSelectVideo = self.allowSelectVideo;
    nav.allowSelectImage = self.allowSelectImage;
    nav.allowSelectGif = self.allowSelectGif;
    nav.allowSelectLivePhoto = self.allowSelectLivePhoto;
    nav.allowTakePhotoInLibrary = self.allowTakePhotoInLibrary;
    nav.allowForceTouch = self.allowForceTouch;
    nav.allowEditImage = self.allowEditImage;
    nav.editAfterSelectThumbnailImage = self.editAfterSelectThumbnailImage;
    nav.clipRatios = self.clipRatios;
    nav.allowMixSelect = self.allowMixSelect;
    nav.showCaptureImageOnTakePhotoBtn = self.showCaptureImageOnTakePhotoBtn;
    nav.sortAscending = self.sortAscending;
    nav.showSelectBtn = self.showSelectBtn;
    nav.isSelectOriginalPhoto = self.isSelectOriginalPhoto;
    nav.navBarColor = self.navBarColor;
    nav.showSelectedMask = self.showSelectedMask;
    nav.selectedMaskColor = self.selectedMaskColor;
    [nav.arrSelectedModels removeAllObjects];
    [nav.arrSelectedModels addObjectsFromArray:self.arrSelectedModels];
    
    return nav;
}

//预览界面
- (void)pushThumbnailViewController
{
    ZLPhotoBrowser *photoBrowser = [[ZLPhotoBrowser alloc] initWithStyle:UITableViewStylePlain];
    ZLImageNavigationController *nav = [self getImageNavWithRootVC:photoBrowser];
    ZLThumbnailViewController *tvc = [[ZLThumbnailViewController alloc] initWithNibName:@"ZLThumbnailViewController" bundle:kZLPhotoBrowserBundle];
    ZLAlbumListModel *m = [ZLPhotoManager getCameraRollAlbumList:self.allowSelectVideo allowSelectImage:self.allowSelectImage];
    tvc.albumListModel = m;
    [nav pushViewController:tvc animated:YES];
    [self.sender presentViewController:nav animated:YES completion:nil];
}

//查看大图界面
- (void)pushBigImageViewControllerWithModels:(NSArray<ZLPhotoModel *> *)models index:(NSInteger)index
{
    ZLShowBigImgViewController *svc = [[ZLShowBigImgViewController alloc] init];
    ZLImageNavigationController *nav = [self getImageNavWithRootVC:svc];
    
    svc.models = models;
    svc.selectIndex = index;
    WeakSelf
    [svc setBtnBackBlock:^(NSArray<ZLPhotoModel *> *selectedModels, BOOL isOriginal,NSArray<UIImage *> *images, NSArray<PHAsset *> *assets) {
        
        [ZLPhotoManager markSelcectModelInArr:weakSelf.arrDataSources selArr:selectedModels];
        weakSelf.isSelectOriginalPhoto = isOriginal;
        [weakSelf.arrSelectedModels removeAllObjects];
        [weakSelf.arrSelectedModels addObjectsFromArray:selectedModels];
        [weakSelf.collectionView reloadData];
        [weakSelf changeCancelBtnTitle];
    }];
    
    [self.sender showDetailViewController:nav sender:nil];
}

- (ZLShowBigImgViewController *)pushBigImageToPreview:(NSArray *)photos index:(NSInteger)index
{
    ZLShowBigImgViewController *svc = [[ZLShowBigImgViewController alloc] init];
    ZLImageNavigationController *nav = [self getImageNavWithRootVC:svc];
    nav.showSelectBtn = YES;
    svc.selectIndex = index;
    svc.arrSelPhotos = [NSMutableArray arrayWithArray:photos];
    svc.models = self.arrSelectedModels;
    
    self.preview = NO;
    [self.sender.view addSubview:self];
    [self.sender showDetailViewController:nav sender:nil];
    
    return svc;
}

- (void)pushEditVCWithModel:(ZLPhotoModel *)model
{
    ZLEditViewController *vc = [[ZLEditViewController alloc] init];
    ZLImageNavigationController *nav = [self getImageNavWithRootVC:vc];
    [nav.arrSelectedModels addObject:model];
    vc.model = model;
    [self.sender showDetailViewController:nav sender:nil];
}

#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    WeakSelf
    [picker dismissViewControllerAnimated:YES completion:^{
        
        if (weakSelf.selectImageBlock && self.allowsEditing && self.maxSelectCount == 1 && self.editAfterSelectThumbnailImage) {
           
            UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
            ZLProgressHUD *hud = [[ZLProgressHUD alloc] init];
            [hud show];
            
            [ZLPhotoManager saveImageToAblum:image completion:^(BOOL suc, PHAsset *asset) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (suc) {
                        ZLPhotoModel *model = [ZLPhotoModel modelWithAsset:asset type:ZLAssetMediaTypeImage duration:nil];
                          [weakSelf.arrSelectedModels addObject:model];
                          [weakSelf pushEditVCWithModel:model];
                          [weakSelf hide];
                    } else {
                        ShowToastLong(@"%@", GetLocalLanguageTextValue(ZLPhotoBrowserSaveImageErrorText));
                    }
                    [hud hide];
                });
            }];
            
            return ;
        }
        
        if (weakSelf.selectImageBlock) {
            UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
            ZLProgressHUD *hud = [[ZLProgressHUD alloc] init];
            [hud show];
            
            [ZLPhotoManager saveImageToAblum:image completion:^(BOOL suc, PHAsset *asset) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (suc) {
                        ZLPhotoModel *model = [ZLPhotoModel modelWithAsset:asset type:ZLAssetMediaTypeImage duration:nil];
                        [weakSelf handleDataArray:model];
                    } else {
                        ShowToastLong(@"%@", GetLocalLanguageTextValue(ZLPhotoBrowserSaveImageErrorText));
                    }
                    [hud hide];
                });
            }];
        }
    }];
}

- (void)handleDataArray:(ZLPhotoModel *)model
{
    [self.arrDataSources insertObject:model atIndex:0];
    if (self.maxSelectCount > 1 && self.arrSelectedModels.count < self.maxSelectCount) {
        model.isSelected = YES;
        [self.arrSelectedModels addObject:model];
        
        [self requestSelPhotos:nil];////////////////
        
    } else if (self.maxSelectCount == 1 && !self.arrSelectedModels.count) {
        model.isSelected = YES;
        [self.arrSelectedModels addObject:model];
        [self requestSelPhotos:nil];
        return;
    }
    [self.collectionView reloadData];
    [self changeCancelBtnTitle];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self hide];
    [picker dismissViewControllerAnimated:YES completion:nil];
    
}

#pragma mark - 获取图片及图片尺寸的相关方法
- (CGSize)getSizeWithAsset:(PHAsset *)asset
{
    CGFloat width  = (CGFloat)asset.pixelWidth;
    CGFloat height = (CGFloat)asset.pixelHeight;
    CGFloat scale = MAX(0.5, width/height);
    
    return CGSizeMake(self.collectionView.frame.size.height*scale, self.collectionView.frame.size.height);
}

@end
