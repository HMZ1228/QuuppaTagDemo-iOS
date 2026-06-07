//
//  TagHistoryManager.h
//  QuuppaTagDemo  v3.0
//
//  Singleton that persists the last 10 Tag IDs used by this device.
//  Thread-safe: all reads/writes serialised on the main queue via NSUserDefaults.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TagHistoryManager : NSObject

/// Shared singleton instance.
+ (instancetype)shared;

/// Add a Tag ID to the front of the history list.
/// Duplicate entries are removed before insertion.
/// The list is automatically capped at 10 entries.
/// @param tagID 12-char uppercase hex string, e.g. @"112233445566"
- (void)addTagID:(NSString *)tagID;

/// Returns up to 10 recent Tag IDs, most recent first.
/// Returns an empty array if no history exists.
- (NSArray<NSString *> *)recentTagIDs;

/// Removes all stored Tag IDs.
- (void)clearHistory;

@end

NS_ASSUME_NONNULL_END
