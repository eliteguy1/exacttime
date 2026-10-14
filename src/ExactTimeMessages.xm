#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
@interface UIDateLabel : UILabel
@property (nonatomic, strong) NSDate *date;
@end

@interface CKConversationListCell : UITableViewCell
@property (nonatomic, strong) id conversation;
@end

@interface CKConversation
@property (nonatomic, strong) NSDate *date;
@end
static bool is24h;
static NSString *settingsPath = @"/var/mobile/Library/Preferences/com.lclrc.exacttimeprefs.plist";
static bool enabled;

%hook CKConversationListCell
-(void)layoutSubviews{
	%orig;
	if(enabled){
		if(MSHookIvar<UIDateLabel *>(self, "_dateLabel")){
			UIDateLabel *dateLabel = MSHookIvar<UIDateLabel *>(self, "_dateLabel");
			if(!dateLabel || !dateLabel.text){
				return;
			}
			if(![dateLabel.text containsString:@":"]){
				NSDate *labelDate = dateLabel.date;
				if(!labelDate && [self respondsToSelector:@selector(conversation)]){
					id conv = [self conversation];
					if(conv && [conv respondsToSelector:@selector(date)]){
						labelDate = [conv date];
					}
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
				dateLabel.text = [dateLabel.text stringByAppendingString:[dateFormatter stringFromDate:labelDate]];
				dateLabel.numberOfLines = 1;
				[dateLabel sizeToFit];
				CGRect f = dateLabel.frame;
				CGFloat maxWidth = self.bounds.size.width - f.origin.x - 8.0;
				if(maxWidth > 0 && f.size.width > maxWidth){
					f.size.width = maxWidth;
					dateLabel.frame = f;
				}
			}
		}
	}
}
%end

%ctor{

	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:settingsPath];
 	id messagesValue = [prefs objectForKey:@"messages"];
 	enabled = (messagesValue ? [(NSNumber *)messagesValue boolValue] : YES);

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[NSLocale currentLocale]];
	[formatter setDateStyle:NSDateFormatterNoStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	NSString *dateString = [formatter stringFromDate:[NSDate date]];
	NSRange amRange = [dateString rangeOfString:[formatter AMSymbol]];
	NSRange pmRange = [dateString rangeOfString:[formatter PMSymbol]];
	is24h = (amRange.location == NSNotFound && pmRange.location == NSNotFound);
}
