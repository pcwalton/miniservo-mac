//
//  MSAppDelegate.h
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MMTabBarView/MMTabBarView.h>
#include <SearchKit/SearchKit.h>
#include <include/cef_app.h>
#include <include/cef_base.h>
#import "INAppStoreWindow.h"

#define MS_HISTORY_BOOKMARKS_AUTOCOMPLETE_SIZE 4

#define MS_INITIAL_URL "http://asdf.com/"

@class MSURLField;
@class MSWebView;

class CefBrowser;
class MSCEFClient;

@interface MSAppDelegate : NSObject <NSApplicationDelegate,
                                     NSTableViewDelegate,
                                     NSTextFieldDelegate,
                                     NSTextViewDelegate,
                                     NSWindowDelegate> {
    CefRefPtr<CefBrowser> mBrowser;
    CefRefPtr<MSCEFClient> mCEFClient;

    NSManagedObjectModel *mManagedObjectModel;
    NSPersistentStoreCoordinator *mPersistentStoreCoordinator;
    NSPopover *mBookmarksPopover;
    NSMutableArray *mSplendidBarHistoryAndBookmarkEntryViews;
    
    SKIndexRef mSearchIndex;
    BOOL mDoingWork;
}

@property (assign) IBOutlet INAppStoreWindow *window;
@property (assign) IBOutlet NSSegmentedControl *backForwardButton;
@property (assign) IBOutlet NSButton *stopReloadButton;
@property (assign) IBOutlet NSTextField *urlBar;
@property (assign) IBOutlet MSWebView *browserView;
@property (assign) IBOutlet MMTabBarView *tabBar;
@property (assign) IBOutlet NSTabView *tabView;
@property (assign) IBOutlet NSView *titleBarView;
@property (assign) IBOutlet NSWindow *statusBarWindow;
@property (assign) IBOutlet NSTextField *statusBar;
@property (assign) IBOutlet NSComboBox *renderingThreadsView;
@property (assign) IBOutlet NSMenuItem *actualSizeMenuItem;
@property (assign) IBOutlet NSMenuItem *zoomInMenuItem;
@property (assign) IBOutlet NSMenuItem *zoomOutMenuItem;
@property (assign) IBOutlet NSMenu *bookmarksMenu;
@property (assign) IBOutlet NSView *bookmarksPopoverView;
@property (assign) IBOutlet NSSegmentedControl *bookmarksButton;
@property (assign) IBOutlet NSArrayController *bookmarksButtonArrayController;
@property (assign) IBOutlet NSWindow *splendidBarWindow;
@property (assign) IBOutlet NSTableView *splendidBarTableView;
@property (assign) IBOutlet NSView *splendidBarSearchResultsSectionView;
@property (assign) IBOutlet NSTextView *splendidBarSearchResultsView;
@property (assign) IBOutlet NSView *urlBarContainer;
@property (assign) IBOutlet NSMenu *historyMenu;
@property (assign) IBOutlet NSView *bookmarksAnimationView;
@property (strong) NSManagedObjectContext *managedObjectContext;

+ (NSString *)URLEncode:(NSString *)query;
- (IBAction)changeFrameworkPath:(id)sender;
- (IBAction)goBackOrForward:(id)sender;
- (IBAction)goBack:(id)sender;
- (IBAction)goForward:(id)sender;
- (IBAction)stopOrReload:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)reload:(id)sender;
- (IBAction)openFile:(id)sender;
- (IBAction)zoomToActualSize:(id)sender;
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;
- (IBAction)bookmarkCurrentPageOrShowBookmarksPopover:(id)sender;
- (IBAction)bookmarkCurrentPage:(id)sender;
- (IBAction)reportBug:(id)sender;
- (IBAction)resetBrowser:(id)sender;
- (void)unbookmarkCurrentPage:(id)sender;
- (void)controlTextDidEndEditing:(NSNotification *)notification;
- (void)showBookmarksPopover;
- (void)updateZoomMenuItems;
- (NSString *)promptForNewFrameworkPath;
- (void)setDisplayedURL:(NSString *)urlString;
- (void)navigateToEnteredURL;
- (void)spinCEFEventLoop:(id)nothing;
- (void)repositionStatusBar;
- (void)windowDidResize:(NSNotification*)notification;
- (void)sendCEFMouseEventForButton:(int)button up:(BOOL)up point:(NSPoint)point;
- (void)sendCEFScrollEventWithDelta:(NSPoint)delta origin:(NSPoint)origin;
- (void)sendCEFKeyboardEventForKey:(short)keyCode character:(char16)character;
- (void)setIsLoading:(BOOL)isLoading;
- (void)updateNavigationState:(id)unused;
- (void)pinchZoom:(CGFloat)zoomLevel;
- (void)initializeCompositing;
- (void)menuDidOpen:(NSNotification *)notification;
- (void)navigateToBookmark:(id)sender;
- (void)navigateToURL:(NSURL *)url;
- (void)populateBookmarksMenu:(id)unused;
- (void)replaceBookmarkMenuItemsWith:(NSArray *)bookmarkIDs;
- (void)closePopoversIfNecessary:(NSEvent *)event;
- (void)navigateToBookmarkAtIndex:(NSInteger)index;
- (void)updateSplendidBarWithSearchAutocompleteData:(NSData *)data;
- (void)searchFor:(NSString *)query;
- (void)textView:(NSTextView *)textView
   clickedOnCell:(id<NSTextAttachmentCell>)cell
          inRect:(NSRect)cellFrame;
- (void)addHistoryEntryForMainFrame:(id)unused;
- (void)performSplendidBarSearch:(NSDictionary *)originalSearchInfo;
- (void)setTabTitle:(NSDictionary *)info;
- (void)determineBookmarkStateForURL:(NSURL *)url;
- (void)updateBookmarkState:(NSNumber *)state;

@end
