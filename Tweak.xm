#import <substrate.h>
#import <notify.h>

#define NSLog(...)

@interface NCNotificationCombinedListViewController : UIViewController
- (BOOL)hasContent;
@end

@interface SBLockScreenManager : NSObject
+(id)sharedInstance;
- (BOOL)isUILocked;
- (BOOL)_attemptUnlockWithPasscode:(id)arg1 mesa:(BOOL)arg2 finishUIUnlock:(BOOL)arg3 completion:(id)arg4;
- (BOOL)_attemptUnlockWithPasscode:(id)arg1 mesa:(BOOL)arg2 finishUIUnlock:(BOOL)arg3;
- (BOOL)_attemptUnlockWithPasscode:(id)arg1 finishUIUnlock:(BOOL)arg2;
- (void)attemptUnlockWithPasscode:(id)arg1 completion:(id)arg2;
- (BOOL)attemptUnlockWithPasscode:(id)arg1;
@end

static BOOL screenIsLocked;
static BOOL isBlackScreen;
static BOOL hasVisibleBulletins;
static NSString* originalPasscode;

static void unlockDeviceNow(NSString* plainTextPassword)
{
	if(!plainTextPassword) {
		return;
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		SBLockScreenManager* SBLockSH = [%c(SBLockScreenManager) sharedInstance];
		if([SBLockSH respondsToSelector:@selector(_attemptUnlockWithPasscode:mesa:finishUIUnlock:completion:)]) {
			[SBLockSH _attemptUnlockWithPasscode:plainTextPassword mesa:0 finishUIUnlock:1 completion:NULL];
		} else if([SBLockSH respondsToSelector:@selector(_attemptUnlockWithPasscode:mesa:finishUIUnlock:)]) {
			[SBLockSH _attemptUnlockWithPasscode:plainTextPassword mesa:0 finishUIUnlock:1];
		} else if([SBLockSH respondsToSelector:@selector(_attemptUnlockWithPasscode:finishUIUnlock:)]) {
			[SBLockSH _attemptUnlockWithPasscode:plainTextPassword finishUIUnlock:1];
		} else if([SBLockSH respondsToSelector:@selector(attemptUnlockWithPasscode:)]) {
			[SBLockSH attemptUnlockWithPasscode:plainTextPassword];
		} else if([SBLockSH respondsToSelector:@selector(attemptUnlockWithPasscode:completion:)]) {
			[SBLockSH attemptUnlockWithPasscode:plainTextPassword completion:NULL];
		}
	});
}

static void passcodeReceived(NSString* plainTextPassword)
{
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		if(!screenIsLocked) {
			originalPasscode = [plainTextPassword copy];
		}
	});
}

%hook SBLockScreenManager
-(void)attemptUnlockWithPasscode:(id)arg1 completion:(/*^block*/id)arg2
{
	%orig;
	if (!originalPasscode) {
		NSLog(@"-(BOOL)attemptUnlockWithPasscode:%@ completion:%@", arg1, arg2);
		passcodeReceived([arg1 copy]);
	}
}
- (BOOL)attemptUnlockWithPasscode:(id)arg1
{
	BOOL r = %orig;
	if (!originalPasscode) {
		NSLog(@"-(BOOL)attemptUnlockWithPasscode:%@", arg1);
		passcodeReceived([arg1 copy]);
	}
	return r;
}
- (BOOL)_attemptUnlockWithPasscode:(id)arg1 mesa:(BOOL)arg2 finishUIUnlock:(BOOL)arg3 completion:(id)arg4
{
	BOOL r = %orig;
	if (!originalPasscode) {
		NSLog(@"-(BOOL)_attemptUnlockWithPasscode:%@ mesa:%@ finishUIUnlock:%@ completion:%@", arg1, @(arg2), @(arg3), arg4);
		passcodeReceived([arg1 copy]);
	}
	return r;
}
%end

%hook SBUIPasscodeLockViewWithKeypad
- (id)statusTitleView
{
	if (!originalPasscode) {
		UILabel *label = MSHookIvar<UILabel *>(self, "_statusTitleView");
		label.text = @"QuickLock requires your passcode each respring";
		return label;
    }
    return %orig;
}
%end

%hook NCNotificationCombinedListViewController
- (void)viewWillLayoutSubviews
{
	%orig;
	hasVisibleBulletins = [self hasContent];
	NSLog(@"viewWillLayoutSubviews[hasVisibleBulletins: %@]:%@ ", @(hasVisibleBulletins), self);
}
%end

static void screenDisplayStatus(CFNotificationCenterRef center, void* observer, CFStringRef name, const void* object, CFDictionaryRef userInfo) {
    uint64_t state;
    int token;
    notify_register_check("com.apple.iokit.hid.displayStatus", &token);
    notify_get_state(token, &state);
    notify_cancel(token);
    if(!state) {
		NSLog(@"display was off");
		isBlackScreen = YES;
    } else {
		isBlackScreen = NO;
		if(screenIsLocked && !hasVisibleBulletins) {
			unlockDeviceNow(originalPasscode);
		}
	}
}

static void screenLockStatus(CFNotificationCenterRef center, void* observer, CFStringRef name, const void* object, CFDictionaryRef userInfo)
{
    uint64_t state;
    int token;
    notify_register_check("com.apple.springboard.lockstate", &token);
    notify_get_state(token, &state);
    notify_cancel(token);
    if (state) {
        screenIsLocked = YES;
    } else {
		NSLog(@"device was unlocked");
        screenIsLocked = NO;
    }
}

%ctor
{
	dlopen("/System/Library/PrivateFrameworks/UserNotificationsUIKit.framework/UserNotificationsUIKit", RTLD_LAZY);
	dlopen("/System/Library/PrivateFrameworks/SpringBoardUIServices.framework/SpringBoardUIServices", RTLD_LAZY);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, screenDisplayStatus, CFSTR("com.apple.iokit.hid.displayStatus"), NULL, 0);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, screenLockStatus, CFSTR("com.apple.springboard.lockstate"), NULL, 0);
	%init;
}
