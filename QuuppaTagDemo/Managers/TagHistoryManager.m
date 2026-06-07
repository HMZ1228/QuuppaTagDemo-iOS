//
//  TagHistoryManager.m
//  QuuppaTagDemo  v3.0
//

#import "TagHistoryManager.h"

static NSString * const kHistoryDefaultsKey = @"quuppa_tagIDHistory";
static const NSInteger   kMaxHistoryCount   = 10;

@implementation TagHistoryManager

+ (instancetype)shared {
    static TagHistoryManager *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)addTagID:(NSString *)tagID {
    if (!tagID.length) return;
    NSString *normalised = tagID.uppercaseString;

    NSMutableArray *history = [self mutableHistory];
    [history removeObject:normalised];          // deduplicate
    [history insertObject:normalised atIndex:0]; // most recent first
    if ((NSInteger)history.count > kMaxHistoryCount) {
        [history removeObjectsInRange:NSMakeRange(kMaxHistoryCount,
                                                  history.count - kMaxHistoryCount)];
    }
    [[NSUserDefaults standardUserDefaults] setObject:[history copy] forKey:kHistoryDefaultsKey];
}

- (NSArray<NSString *> *)recentTagIDs {
    return [[NSUserDefaults standardUserDefaults] arrayForKey:kHistoryDefaultsKey] ?: @[];
}

- (void)clearHistory {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kHistoryDefaultsKey];
}

#pragma mark - Private

- (NSMutableArray *)mutableHistory {
    NSArray *stored = [[NSUserDefaults standardUserDefaults] arrayForKey:kHistoryDefaultsKey];
    return stored ? [stored mutableCopy] : [NSMutableArray array];
}

@end
