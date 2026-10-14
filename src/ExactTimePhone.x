#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface UIDateLabel : UILabel
@property (nonatomic, strong) NSDate *date;
@end

@interface MPRecentsTableViewCell : UITableViewCell
@property (nonatomic, strong) UIDateLabel *callerDateLabel;
@end

@interface CHRecentCall : NSObject
@property (nonatomic, strong) NSDate *date;
@end

@interface MPRecentsTableViewController : NSObject
- (id)recentCallAtTableViewIndex:(NSInteger)index;
@end

static bool is24h;
static NSString *settingsPath = @"/var/mobile/Library/Preferences/com.lclrc.exacttimeprefs.plist";
static bool enabled;
static char kExactTimeCallDateKey;

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
	if(enabled){
		UIDateLabel *label = self.callerDateLabel;
		if(!label || !label.text){
			return;
		}
		if(![label.text containsString:@":"]){
		NSDate *labelDate = label.date;
		if(!labelDate){
			labelDate = objc_getAssociatedObject(self, &kExactTimeCallDateKey);
		}
		if(!labelDate){
			return;
		}
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		if(is24h){
			[dateFormatter setDateFormat:@" • HH:mm"];
		}else{
			[dateFormatter setDateFormat:@" • h:mm a"];
		}

		label.textAlignment = 2;
		label.numberOfLines = 1;
		label.text = [label.text stringByAppendingString:[dateFormatter stringFromDate:labelDate]];
		[label sizeToFit];
		}
	}
}
%end

%ctor{

	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:settingsPath];
	id phoneValue = [prefs objectForKey:@"phone"];
	enabled = (phoneValue ? [(NSNumber *)phoneValue boolValue] : YES);

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[NSLocale currentLocale]];
	[formatter setDateStyle:NSDateFormatterNoStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	NSString *dateString = [formatter stringFromDate:[NSDate date]];
	NSRange amRange = [dateString rangeOfString:[formatter AMSymbol]];
	NSRange pmRange = [dateString rangeOfString:[formatter PMSymbol]];
	is24h = (amRange.location == NSNotFound && pmRange.location == NSNotFound);
}
