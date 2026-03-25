#import <SafariServices/SafariServices.h>

#include "jni.h"
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>

#include "utils.h"

CFTypeRef SecTaskCopyValueForEntitlement(void* task, NSString* entitlement, CFErrorRef  _Nullable *error);
void* SecTaskCreateFromSelf(CFAllocatorRef allocator);

BOOL getEntitlementValue(NSString *key) {
    void *secTask = SecTaskCreateFromSelf(NULL);
    CFTypeRef value = SecTaskCopyValueForEntitlement(SecTaskCreateFromSelf(NULL), key, nil);
    if (value != nil) {
        CFRelease(value);
    }
    CFRelease(secTask);

    return value != nil && [(__bridge id)value boolValue];
}

BOOL isJITEnabled(BOOL checkCSFlags) {
    if (!checkCSFlags && (getEntitlementValue(@"dynamic-codesigning") || isJailbroken)) {
        return YES;
    }

    int flags;
    csops(getpid(), 0, &flags, sizeof(flags));
    return (flags & CS_DEBUGGED) != 0;
}

void openLink(UIViewController* sender, NSURL* link) {
    if (NSClassFromString(@"SFSafariViewController") == nil) {
        NSData *data = [link.absoluteString dataUsingEncoding:NSUTF8StringEncoding];
        CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
        [filter setValue:data forKey:@"inputMessage"];
        UIImage *image = [UIImage imageWithCIImage:filter.outputImage scale:1.0 orientation:UIImageOrientationUp];
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(300, 300), NO, 0.0);
        CGRect frame = CGRectMake(0, 0, 300, 300);
        [image drawInRect:frame];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:frame];
        imageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil
            message:link.absoluteString
            preferredStyle:UIAlertControllerStyleAlert];

        UIViewController *vc = UIViewController.new;
        vc.view = imageView;
        [alert setValue:vc forKey:@"contentViewController"];

        UIAlertAction* doneAction = [UIAlertAction actionWithTitle:localize(@"Done", nil) style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:doneAction];
        [sender presentViewController:alert animated:YES completion:nil];
    } else {
        SFSafariViewController *vc = [[SFSafariViewController alloc] initWithURL:link];
        [sender presentViewController:vc animated:YES completion:nil];
    }
}

NSMutableDictionary* parseJSONFromFile(NSString *path) {
    NSError *error;

    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (content == nil) {
        NSLog(@"[ParseJSON] Error: could not read %@: %@", path, error.localizedDescription);
        return @{@"NSErrorObject": error}.mutableCopy;
    }

    NSData* data = [content dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if (error) {
        NSLog(@"[ParseJSON] Error: could not parse JSON: %@", error.localizedDescription);
        return @{@"NSErrorObject": error}.mutableCopy;
    }
    return dict;
}

NSError* saveJSONToFile(NSDictionary *dict, NSString *path) {
    // TODO: handle rename
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    if (jsonData == nil) {
        return error;
    }
    BOOL success = [jsonData writeToFile:path options:NSDataWritingAtomic error:&error];
    if (!success) {
        return error;
    }
    return nil;
}

NSString* localize(NSString* key, NSString* comment) {
    NSString *value = NSLocalizedString(key, nil);
    if (![NSLocale.preferredLanguages[0] isEqualToString:@"en"] && [value isEqualToString:key]) {
        NSString* path = [NSBundle.mainBundle pathForResource:@"en" ofType:@"lproj"];
        NSBundle* languageBundle = [NSBundle bundleWithPath:path];
        value = [languageBundle localizedStringForKey:key value:nil table:nil];

        if ([value isEqualToString:key]) {
            value = [[NSBundle bundleWithIdentifier:@"com.apple.UIKit"] localizedStringForKey:key value:nil table:nil];
        }
    }

    return value;
}

void customNSLog(const char *file, int lineNumber, const char *functionName, NSString *format, ...)
{
    va_list ap; 
    va_start (ap, format);
    NSString *body = [[NSString alloc] initWithFormat:format arguments:ap];
    printf("%s", [body UTF8String]);
    if (![format hasSuffix:@"\n"]) {
        printf("\n");
    }
    va_end (ap);
}

CGFloat MathUtils_dist(CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2) {
    const CGFloat x = (x2 - x1);
    const CGFloat y = (y2 - y1);
    return (CGFloat) hypot(x, y);
}

//Ported from https://www.arduino.cc/reference/en/language/functions/math/map/
CGFloat MathUtils_map(CGFloat x, CGFloat in_min, CGFloat in_max, CGFloat out_min, CGFloat out_max) {
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

CGFloat dpToPx(CGFloat dp) {
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    return dp * screenScale;
}

CGFloat pxToDp(CGFloat px) {
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    return px / screenScale;
}

void setButtonPointerInteraction(UIButton *button) {
    button.pointerInteractionEnabled = YES;
    button.pointerStyleProvider = ^ UIPointerStyle* (UIButton* button, UIPointerEffect* proposedEffect, UIPointerShape* proposedShape) {
        UITargetedPreview *preview = [[UITargetedPreview alloc] initWithView:button];
        return [NSClassFromString(@"UIPointerStyle") styleWithEffect:[NSClassFromString(@"UIPointerHighlightEffect") effectWithPreview:preview] shape:proposedShape];
    };
}

UIColor* PLAccentColor(void) {
    return [UIColor colorWithRed:124/255.0 green:78/255.0 blue:232/255.0 alpha:1.0];
}

UIColor* PLSecondaryAccentColor(void) {
    return [UIColor colorWithRed:88/255.0 green:197/255.0 blue:255/255.0 alpha:1.0];
}

UIColor* PLBackgroundColor(void) {
    if (@available(iOS 13.0, *)) {
        return UIColor.systemGroupedBackgroundColor;
    }
    return [UIColor colorWithWhite:0.96 alpha:1.0];
}

UIColor* PLCardColor(void) {
    if (@available(iOS 13.0, *)) {
        return UIColor.secondarySystemGroupedBackgroundColor;
    }
    return [UIColor colorWithWhite:1.0 alpha:1.0];
}

UIColor* PLMutedTextColor(void) {
    if (@available(iOS 13.0, *)) {
        return UIColor.secondaryLabelColor;
    }
    return [UIColor colorWithWhite:0.35 alpha:1.0];
}

UIView* PLCardBackgroundView(CGFloat cornerRadius, UIColor *color) {
    UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
    backgroundView.backgroundColor = color ?: PLCardColor();
    backgroundView.layer.cornerRadius = cornerRadius;
    if ([backgroundView.layer respondsToSelector:@selector(setCornerCurve:)]) {
        backgroundView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    backgroundView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    backgroundView.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
    return backgroundView;
}

void PLApplyNavigationAppearance(UINavigationController *navigationController) {
    if (!navigationController) return;
    navigationController.view.backgroundColor = PLBackgroundColor();
    navigationController.navigationBar.tintColor = PLAccentColor();
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = [PLBackgroundColor() colorWithAlphaComponent:0.82];
        appearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        appearance.shadowColor = UIColor.clearColor;
        appearance.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.labelColor};
        appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: UIColor.labelColor};
        navigationController.navigationBar.standardAppearance = appearance;
        navigationController.navigationBar.compactAppearance = appearance;
        navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
}

void PLApplyToolbarAppearance(UIToolbar *toolbar) {
    if (!toolbar) return;
    toolbar.tintColor = PLAccentColor();
    if (@available(iOS 13.0, *)) {
        UIToolbarAppearance *appearance = [[UIToolbarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = [PLBackgroundColor() colorWithAlphaComponent:0.78];
        appearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        appearance.shadowColor = UIColor.clearColor;
        toolbar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            toolbar.scrollEdgeAppearance = appearance;
        }
    }
}

void PLStylePrimaryButton(UIButton *button) {
    if (!button) return;
    button.backgroundColor = PLAccentColor();
    button.tintColor = UIColor.whiteColor;
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [button setTitleColor:[UIColor.whiteColor colorWithAlphaComponent:0.6] forState:UIControlStateDisabled];
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 18);
    button.layer.cornerRadius = 16.0;
    if ([button.layer respondsToSelector:@selector(setCornerCurve:)]) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.layer.shadowColor = PLAccentColor().CGColor;
    button.layer.shadowOpacity = 0.22;
    button.layer.shadowRadius = 16.0;
    button.layer.shadowOffset = CGSizeMake(0, 10);
}

void PLStyleInputField(UITextField *textField) {
    if (!textField) return;
    textField.backgroundColor = [PLCardColor() colorWithAlphaComponent:0.96];
    textField.textColor = UIColor.labelColor;
    textField.tintColor = PLAccentColor();
    textField.layer.cornerRadius = 14.0;
    if ([textField.layer respondsToSelector:@selector(setCornerCurve:)]) {
        textField.layer.cornerCurve = kCACornerCurveContinuous;
    }
    textField.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    textField.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
}

void PLStyleAvatarView(UIImageView *imageView, CGFloat cornerRadius) {
    if (!imageView) return;
    imageView.clipsToBounds = YES;
    imageView.layer.cornerRadius = cornerRadius;
    if ([imageView.layer respondsToSelector:@selector(setCornerCurve:)]) {
        imageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    imageView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    imageView.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
}

void PLStyleTableCell(UITableViewCell *cell) {
    if (!cell) return;
    cell.backgroundColor = UIColor.clearColor;
    cell.backgroundView = PLCardBackgroundView(18.0, [PLCardColor() colorWithAlphaComponent:0.92]);
    cell.selectedBackgroundView = PLCardBackgroundView(18.0, [PLAccentColor() colorWithAlphaComponent:0.16]);
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    cell.detailTextLabel.textColor = PLMutedTextColor();
    cell.separatorInset = UIEdgeInsetsMake(0, 58, 0, 16);
}

__attribute__((noinline,optnone,naked))
void* JIT26CreateRegionLegacy(size_t len) {
    asm("brk #0x69 \n"
        "ret");
}
__attribute__((noinline,optnone,naked))
void* JIT26PrepareRegion(void *addr, size_t len) {
    asm("mov x16, #1 \n"
        "brk #0xf00d \n"
        "ret");
}
__attribute__((noinline,optnone,naked))
void BreakSendJITScript(char* script, size_t len) {
   asm("mov x16, #2 \n"
       "brk #0xf00d \n"
       "ret");
}
__attribute__((noinline,optnone,naked))
void JIT26SetDetachAfterFirstBr(BOOL value) {
   asm("mov x16, #3 \n"
       "brk #0xf00d \n"
       "ret");
}
__attribute__((noinline,optnone,naked))
void JIT26PrepareRegionForPatching(void *addr, size_t size) {
   asm("mov x16, #4 \n"
       "brk #0xf00d \n"
       "ret");
}
void JIT26SendJITScript(NSString* script) {
    NSCAssert(script, @"Script must not be nil");
    BreakSendJITScript((char*)script.UTF8String, script.length);
}
BOOL DeviceRequiresTXMWorkaround(void) {
    if (@available(iOS 26.0, *)) {
        DIR *d = opendir("/private/preboot");
        if(!d) return NO;
        struct dirent *dir;
        char txmPath[PATH_MAX];
        while ((dir = readdir(d)) != NULL) {
            if(strlen(dir->d_name) == 96) {
                snprintf(txmPath, sizeof(txmPath), "/private/preboot/%s/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", dir->d_name);
                break;
            }
        }
        closedir(d);
        return access(txmPath, F_OK) == 0;
    }
    return NO;
}
