#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface UIDateLabel : UILabel
@property (nonatomic, strong) NSDate *date;
@end

@interface CHRecentCall : NSObject
@property (nonatomic, strong) NSDate *date;
@end

@interface MPRecentsTableViewController : NSObject
- (id)recentCallAtTableViewIndex:(NSInteger)index;
@end

@interface MPRecentsTableViewCell : UITableViewCell
@property (nonatomic, strong) UIDateLabel *callerDateLabel;
@end

static bool is24h;
static NSString *settingsPath = @"/var/mobile/Library/Preferences/com.lclrc.exacttimeprefs.plist";
static bool enabled = YES;
static char kExactTimeCallDateKey;

static void LogPhone(NSString *msg) {
    NSString *path = @"/var/mobile/exacttime_phone.log";
    FILE *f = fopen([path UTF8String], "a");
    if (f) {
        fprintf(f, "%s\n", [msg UTF8String]);
        fclose(f);
    }
}

// Find date label in a cell
static UILabel *FindDateLabelInView(UIView *view) {
    if ([view isKindOfClass:objc_getClass("UIDateLabel")]) {
        return (UILabel *)view;
    }
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *lbl = (UILabel *)view;
        NSString *txt = lbl.text;
        if (txt && txt.length > 0 && ![txt containsString:@" • "] && ![txt containsString:@":"]) {
            CGRect frame = [view convertRect:view.bounds toView:nil];
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            if (frame.origin.x > screenWidth * 0.35) {
                if ([txt isEqualToString:@"어제"] || [txt isEqualToString:@"오늘"] || [txt isEqualToString:@"그저께"] ||
                    [txt hasSuffix:@"요일"] || [txt isEqualToString:@"Yesterday"] || [txt isEqualToString:@"Today"] ||
                    [txt containsString:@"년"] || [txt containsString:@"월"] || [txt containsString:@"일"] ||
                    [txt containsString:@"/"] || [txt containsString:@"-"] || [txt containsString:@"."]) {
                    return lbl;
                }
            }
        }
    }
    for (UIView *sub in view.subviews) {
        UILabel *found = FindDateLabelInView(sub);
        if (found) return found;
    }
    return nil;
}

// Extract NSDate from cell or label
static NSDate *ExtractDateFromCell(UIView *cell, UILabel *label) {
    // 1. Check label itself
    if (label && [label respondsToSelector:@selector(date)]) {
        id d = [label performSelector:@selector(date)];
        if ([d isKindOfClass:[NSDate class]]) {
            return (NSDate *)d;
        }
    }
    // 2. Check associated object
    id assoc = objc_getAssociatedObject(cell, &kExactTimeCallDateKey);
    if ([assoc isKindOfClass:[NSDate class]]) {
        return (NSDate *)assoc;
    }
    // 3. Check cell methods
    NSArray *selectors = @[@"recentCall", @"call", @"callItem", @"item", @"representedObject", @"callObject"];
    for (NSString *selName in selectors) {
        SEL sel = NSSelectorFromString(selName);
        if ([cell respondsToSelector:sel]) {
            id obj = [cell performSelector:sel];
            if (obj && [obj respondsToSelector:@selector(date)]) {
                id d = [obj performSelector:@selector(date)];
                if ([d isKindOfClass:[NSDate class]]) {
                    return (NSDate *)d;
                }
            }
        }
    }
    // 4. Check ivars of cell
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList([cell class], &ivarCount);
    if (ivars) {
        for (unsigned int i = 0; i < ivarCount; i++) {
            id val = object_getIvar(cell, ivars[i]);
            if (val) {
                if ([val isKindOfClass:[NSDate class]]) {
                    free(ivars);
                    return (NSDate *)val;
                }
                if ([val respondsToSelector:@selector(date)]) {
                    id d = [val performSelector:@selector(date)];
                    if ([d isKindOfClass:[NSDate class]]) {
                        free(ivars);
                        return (NSDate *)d;
                    }
                }
            }
        }
        free(ivars);
    }
    return nil;
}

static void ProcessCell(UIView *cell) {
    if (!enabled) return;
    UILabel *label = nil;
    if ([cell respondsToSelector:@selector(callerDateLabel)]) {
        label = [cell performSelector:@selector(callerDateLabel)];
    }
    if (!label) {
        label = FindDateLabelInView(cell);
    }
    if (!label || !label.text) return;
    if ([label.text containsString:@" • "] || [label.text containsString:@":"]) return;

    NSDate *date = ExtractDateFromCell(cell, label);
    static int logCount = 0;
    if (logCount++ < 15) {
        LogPhone([NSString stringWithFormat:@"[ExactTimePhone] Cell=%@, Label=%@ (text='%@'), Date=%@",
            NSStringFromClass([cell class]), NSStringFromClass([label class]), label.text, date]);
    }

    if (date) {
        NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
        if (is24h) {
            [dateFormatter setDateFormat:@" • HH:mm"];
        } else {
            [dateFormatter setDateFormat:@" • h:mm a"];
        }
        label.numberOfLines = 1;
        label.text = [label.text stringByAppendingString:[dateFormatter stringFromDate:date]];
        [label sizeToFit];
    }
}

%hook MPRecentsTableViewController
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	UITableViewCell *cell = %orig;
	if(cell && [self respondsToSelector:@selector(recentCallAtTableViewIndex:)]){
		id call = [self recentCallAtTableViewIndex:indexPath.row];
		NSDate *callDate = nil;
		if(call && [call respondsToSelector:@selector(date)]){
			callDate = [call date];
		}
		objc_setAssociatedObject(cell, &kExactTimeCallDateKey, callDate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return cell;
}
%end

%hook MPRecentsTableViewCell
-(void)layoutSubviews{
	%orig;
	ProcessCell(self);
}
%end

%hook UITableViewCell
-(void)layoutSubviews{
	%orig;
	ProcessCell(self);
}
%end

%hook UICollectionViewCell
-(void)layoutSubviews{
	%orig;
	ProcessCell(self);
}
%end

%ctor{
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:settingsPath];
	id phoneValue = [prefs objectForKey:@"phone"];
	enabled = (phoneValue ? [(NSNumber *)phoneValue boolValue] : YES);
	[prefs release];

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[NSLocale currentLocale]];
	[formatter setDateStyle:NSDateFormatterNoStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	NSString *dateString = [formatter stringFromDate:[NSDate date]];
	NSRange amRange = [dateString rangeOfString:[formatter AMSymbol]];
	NSRange pmRange = [dateString rangeOfString:[formatter PMSymbol]];
	is24h = (amRange.location == NSNotFound && pmRange.location == NSNotFound);
	[formatter release];

	LogPhone(@"=== ExactTimePhone ctor initialized ===");
}
