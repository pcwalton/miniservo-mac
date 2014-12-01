//
//  MSAppDelegate.mm
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#import "MSAppDelegate.h"
#import "MSBookmark.h"
#import "MSCEFClient.h"
#import "MSHistoryEntry.h"
#import "MSSearchResultCell.h"
#import "MSSplendidBarResultView.h"
#import "MSTabModel.h"
#import "MSTabStyle.h"
#import "MSURLField.h"
#import "MSView.h"
#import "NSString+MSStringAdditions.h"
#import <MMTabBarView/MMAttachedTabBarButton.h>
#include <SearchKit/SearchKit.h>
#include <include/cef_app.h>
#include <include/cef_base.h>
#include <include/cef_browser.h>
#include <include/cef_client.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <dlfcn.h>

#define BACK_SEGMENT    0
#define FORWARD_SEGMENT 1

#define BOOKMARK_SEGMENT        0
#define SHOW_BOOKMARKS_SEGMENT  1

#define BOOKMARKS_TAG       0xb00c
#define HISTORY_MENU_SIZE   15

#define SPLENDID_BAR_TOP_SPACING    0.0
#define SPLENDID_BAR_ROW_HEIGHT     40.0

#define SEARCH_AUTOCOMPLETE_URL \
    @"http://suggestqueries.google.com/complete/search?client=firefox&q=${QUERY}"
#define SEARCH_URL @"http://google.com/search?q=${QUERY}"
#define REPORT_BUG_URL  @"http://github.com/servo/servo/issues"

// http://boredzo.org/blog/archives/2007-05-22/virtual-key-codes
#define KEY_CODE_LEFT   123
#define KEY_CODE_RIGHT  124
#define KEY_CODE_DOWN   125
#define KEY_CODE_UP     126

@implementation MSAppDelegate

- (id)init {
    self = [super init];
    return self;
}

- (IBAction)changeFrameworkPath:(id)sender
{
    NSString *newFrameworkPath = [self promptForNewFrameworkPath];
    if (newFrameworkPath != nil) {
        [[NSUserDefaults standardUserDefaults] setObject: newFrameworkPath
                                                  forKey: @"ServoFrameworkPath"];
    }
}

- (NSString *)promptForNewFrameworkPath
{
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setTreatsFilePackagesAsDirectories:YES];
    [openPanel setAllowedFileTypes: [NSArray arrayWithObject: @"dylib"]];
    
    NSURL *helpURL = [[NSBundle mainBundle] URLForResource:@"ServoLibrarySelectionHelp.rtf"
                                             withExtension:nil];
    NSTextView *helpLabel =
        [[NSTextView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 600.0, 100.0)];
    [helpLabel replaceCharactersInRange: NSMakeRange(0, 0)
                                withRTF:[NSData dataWithContentsOfURL: helpURL]];
    [helpLabel setEditable:NO];
    [helpLabel setDrawsBackground:NO];
    [helpLabel sizeToFit];
    [openPanel setAccessoryView:helpLabel];
    
    if ([openPanel runModal] != NSFileHandlingPanelOKButton)
        return nil;
    return [[[openPanel URLs] objectAtIndex:0] path];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:
     [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1]
                                 forKey:@"ServoRenderingThreads"]];
    
    // Register delegates.
    [self.window setDelegate:self];
    [self.browserView setAppDelegate:self];
    [self.urlBar setDelegate:self];
    [self.splendidBarTableView setDelegate:self];
    [self.splendidBarSearchResultsView setDelegate:self];

    // Register notifications.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(menuDidOpen:)
                                                 name:NSMenuDidBeginTrackingNotification
                                               object:nil];
    
    // Set up the tab view.
    [self.tabView addTabViewItem:[[NSTabViewItem alloc] initWithIdentifier:
                                  [[MSTabModel alloc] init]]];

    self.window.titleBarView = self.titleBarView;
    self.window.centerTrafficLightButtons = NO;
    self.window.centerFullScreenButton = NO;
    self.window.trafficLightButtonsLeftMargin =
        self.window.trafficLightButtonsTopMargin =
        self.window.fullScreenButtonRightMargin =
        self.window.fullScreenButtonTopMargin = 14.0;
    [self.window setTitleBarHeight: [self.titleBarView frame].size.height + 20.0];

    [self.statusBarWindow setStyleMask:NSBorderlessWindowMask];
    [self.statusBarWindow setOpaque:NO];
    [self.statusBarWindow setBackgroundColor:[NSColor clearColor]];
    [self.window addChildWindow:self.statusBarWindow ordered:NSWindowAbove];
    
    // Set up the tab bar.
    [self.tabBar setButtonMaxWidth:9999];
    [self.tabBar setButtonOptimumWidth:9999];
    [self.tabBar setShowAddTabButton:YES];
    [self.tabBar setAutomaticallyAnimates:YES];
    [self.tabBar setStyle: [[MSTabStyle alloc] init]];
    
    // Set up the popover.
    mBookmarksPopover = nil;
    
    // Set up the Splendid Bar.
    mSplendidBarHistoryAndBookmarkEntryViews = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < MS_HISTORY_BOOKMARKS_AUTOCOMPLETE_SIZE; i++)
        [mSplendidBarHistoryAndBookmarkEntryViews addObject:[NSNull null]];
    
    // Initialize data stores and preferences.
    [self reinitializeDataStores];
    [self reinitializePreferences];
    
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    char **cArguments = new char *[[arguments count]];
    for (size_t i = 0; i < [arguments count]; i++)
        cArguments[i] = strdup([[arguments objectAtIndex: i] cString]);
    CefMainArgs mainArgs((int)[arguments count], cArguments);
    
    CefSettings settings;
    settings.single_process = true;
    settings.rendering_threads =
        (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"ServoRenderingThreads"];
    CefInitialize(mainArgs, settings, nullptr, nullptr);

    mCEFClient = new MSCEFClient(self, self.browserView);
    
    CefWindowInfo windowInfo;
    windowInfo.SetAsWindowless([self browserView], false);
    CefBrowserSettings browserSettings;
    mBrowser = CefBrowserHost::CreateBrowserSync(windowInfo,
                                                 mCEFClient,
                                                 MS_INITIAL_URL,
                                                 browserSettings,
                                                 nullptr);

    [self.browserView initializeCompositing];
    [self updateZoomMenuItems];

    [NSEvent addLocalMonitorForEventsMatchingMask:NSAnyEventMask handler:^(NSEvent* event) {
        [self performSelectorOnMainThread:@selector(spinCEFEventLoop:)
                               withObject:nil
                            waitUntilDone:NO];
        return event;
    }];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSLeftMouseDownMask
                                          handler:^(NSEvent* event) {
        [self performSelectorOnMainThread:@selector(closePopoversIfNecessary:)
                               withObject:event
                            waitUntilDone:NO];
        return event;
    }];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask
                                          handler:^(NSEvent* event) {
        if ([event keyCode] == KEY_CODE_LEFT && ([event modifierFlags] & NSCommandKeyMask)) {
            [self performSelectorOnMainThread:@selector(goBack:)
                                   withObject:self
                                waitUntilDone:NO];
            return event;
        }
        if ([event keyCode] == KEY_CODE_RIGHT && ([event modifierFlags] & NSCommandKeyMask)) {
            [self performSelectorOnMainThread:@selector(goForward:)
                                   withObject:self
                                waitUntilDone:NO];
            return event;
        }
        if ([event keyCode] == KEY_CODE_DOWN || [event keyCode] == KEY_CODE_UP) {
            [self performSelectorOnMainThread:@selector(arrowKeyDown:)
                                   withObject:event
                                waitUntilDone:NO];
            return event;
        }
        return event;
    }];
}

- (void)spinCEFEventLoop:(id) nothing {
    CefDoMessageLoopWork();
}

- (IBAction)goBackOrForward:(id)sender {
    NSSegmentedControl* control = (NSSegmentedControl*)sender;
    switch ([control selectedSegment]) {
    case BACK_SEGMENT:
        [self goBack:sender];
        break;
    case FORWARD_SEGMENT:
        [self goForward:sender];
        break;
    }
}

- (IBAction)goBack:(id)sender {
    mBrowser->GoBack();
}

- (IBAction)goForward:(id)sender {
    mBrowser->GoForward();
}

- (IBAction)stopOrReload:(id)sender {
    if (mBrowser->IsLoading())
        mBrowser->StopLoad();
    else
        mBrowser->Reload();
}

- (IBAction)openFile:(id)sender {
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setTreatsFilePackagesAsDirectories:YES];
    [openPanel setAllowedFileTypes: [NSArray arrayWithObjects: @"htm", @"html", nil]];
    if ([openPanel runModal] != NSFileHandlingPanelOKButton)
        return;
    NSURL *url = [[openPanel URLs] objectAtIndex:0];
    [self.urlBar setStringValue: [url description]];
    [self navigateToEnteredURL];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if (![self.splendidBarWindow isVisible]) {
        NSRect windowFrame = [[self.urlBarContainer window] frame];
        NSRect urlBarFrame = [self.urlBarContainer frame];
        CGFloat splendidBarHeight = [self.splendidBarWindow frame].size.height;
        NSRect splendidBarFrame =
        NSMakeRect(urlBarFrame.origin.x + windowFrame.origin.x,
                   (windowFrame.size.height - urlBarFrame.origin.y) + windowFrame.origin.y -
                    splendidBarHeight - urlBarFrame.size.height - SPLENDID_BAR_TOP_SPACING,
                   urlBarFrame.size.width,
                   splendidBarHeight);
        [self.splendidBarWindow setFrame:splendidBarFrame display:NO];
        [self.splendidBarWindow setOpaque:NO];
        [self.splendidBarWindow setBackgroundColor:[NSColor clearColor]];
        [self.splendidBarWindow makeKeyAndOrderFront:self];
    }
        
    [self asynchronouslyUpdateSplendidBar];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    if ([[[notification userInfo] objectForKey:@"NSTextMovement"] intValue] != NSReturnTextMovement)
        return;
    
    [self navigateToEnteredURL];
}

+ (NSString *)URLEncode:(NSString *)query {
    return (NSString *)CFBridgingRelease(
        CFURLCreateStringByAddingPercentEscapes(nullptr,
                                                (CFStringRef)query,
                                                NULL,
                                                CFSTR("!*'();:@&=+$,/?%#[]"),
                                                kCFStringEncodingUTF8));
}

- (void)asynchronouslyUpdateSplendidBar {
    NSString *query = [self.urlBar stringValue];
    
    // Start updating search autocomplete suggestions.
    NSString *escapedQuery = [MSAppDelegate URLEncode:query];
    NSURL *url = [[NSURL alloc] initWithString:
                  [SEARCH_AUTOCOMPLETE_URL stringByReplacingOccurrencesOfString:@"${QUERY}"
                                                                     withString:escapedQuery]];
    NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:url];
    [NSURLConnection sendAsynchronousRequest:urlRequest
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *connectionError) {
                               if (data == nil)
                                   return;
                               [self updateSplendidBarWithSearchAutocompleteData:data];
                           }];
    
    // Start updating history/bookmarks.
    [self performSelectorInBackground:@selector(performSplendidBarSearch:) withObject:query];
}

- (void)updateSplendidBarWithSearchAutocompleteData:(NSData *)data {
    NSArray *responseArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSMutableAttributedString *searchResultsString =
        [self.splendidBarSearchResultsView textStorage];
    [searchResultsString deleteCharactersInRange:NSMakeRange(0, [searchResultsString length])];
    for (NSString *completion in [responseArray objectAtIndex:1]) {
        NSTextAttachment *attachment =
            [[NSTextAttachment alloc] initWithFileWrapper:[[NSFileWrapper alloc]
                                                           initWithPath:@"/dev/null"]];
        MSSearchResultCell *searchResultCell = [[MSSearchResultCell alloc] init];
        searchResultCell.text = completion;
        [attachment setAttachmentCell:searchResultCell];
        NSAttributedString *attributedString =
        [NSAttributedString attributedStringWithAttachment:attachment];
        [searchResultsString appendAttributedString:attributedString];
        [searchResultsString appendAttributedString:
         [[NSAttributedString alloc] initWithString: @" "]];
    }

    [self.splendidBarTableView beginUpdates];
    if ([self.splendidBarTableView numberOfRows] == 0) {
        [self.splendidBarTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:0]
                                         withAnimation:NSTableViewAnimationEffectFade];
    }
    [self.splendidBarTableView endUpdates];
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    if (row == [tableView numberOfRows] - 1)
        return self.splendidBarSearchResultsSectionView;
    if (row < [mSplendidBarHistoryAndBookmarkEntryViews count])
        return [mSplendidBarHistoryAndBookmarkEntryViews objectAtIndex:row];
    return nil;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return [self.splendidBarSearchResultsSectionView frame].size.height;
}

- (void)navigateToEnteredURL {
    NSString *string = [self.urlBar stringValue];
    if ([string length] == 0)
        return;
    NSURL *url = [NSURL URLWithString:string];
    if ([url scheme] == nil) {
        string = [@"http://" stringByAppendingString:string];
        url = [NSURL URLWithString:string];
    }

    [self.splendidBarWindow orderOut:self];
    [self navigateToURL:url];
}

- (void)setDisplayedURL:(NSString *)urlString {
    NSURL *url = [[NSURL alloc] initWithString:urlString];
    
    NSDictionary *dimmedAttributes = [NSDictionary
                                      dictionaryWithObjectsAndKeys:
                                      [NSColor disabledControlTextColor],
                                      NSForegroundColorAttributeName,
                                      [NSFont systemFontOfSize:12.0],
                                      NSFontAttributeName,
                                      nil];
    NSDictionary *darkAttributes = [NSDictionary
                                    dictionaryWithObjectsAndKeys:
                                    [NSColor controlTextColor],
                                    NSForegroundColorAttributeName,
                                    [NSFont systemFontOfSize:12.0],
                                    NSFontAttributeName,
                                    nil];
    NSMutableAttributedString *formattedURL = [[NSMutableAttributedString alloc] init];
    [formattedURL appendAttributedString:
     [[NSAttributedString alloc] initWithString:[[url scheme] stringByAppendingString:@"://"]
                                     attributes:dimmedAttributes]];
    // TODO(pcwalton): username, password, port
    NSString *host = [url host];
    if (host == nil)
        host = [[NSString alloc] init];
    [formattedURL appendAttributedString:
     [[NSAttributedString alloc] initWithString:host
                                     attributes:darkAttributes]];
    [formattedURL appendAttributedString:
     [[NSAttributedString alloc] initWithString:[url path]
                                     attributes:dimmedAttributes]];
    [self.urlBar setAttributedStringValue: formattedURL];
}

- (void)repositionStatusBar {
    [self.statusBarWindow setFrame:NSMakeRect([self.window frame].origin.x,
                                              [self.window frame].origin.y,
                                              [self.window frame].size.width,
                                              [self.statusBarWindow frame].size.height)
                           display:YES];
    
}

- (void)windowDidResize:(NSNotification*)notification {
    [self repositionStatusBar];
    
    if (mBrowser == nullptr)
        return;
    [self.browserView updateGLContext];
    mBrowser->GetHost()->WasResized();
    mBrowser->GetHost()->Invalidate(PET_VIEW);
}

- (void)sendCEFMouseEventForButton:(int)button up:(BOOL)up point:(NSPoint)point {
    cef_mouse_event_t cCefMouseEvent;
    cCefMouseEvent.x = point.x;
    cCefMouseEvent.y = point.y;
    CefMouseEvent cefMouseEvent(cCefMouseEvent);
    mBrowser->GetHost()->SendMouseClickEvent(cefMouseEvent, MBT_LEFT, up, 1);
}

- (void)sendCEFScrollEventWithDelta:(NSPoint)delta origin:(NSPoint)origin {
    cef_mouse_event_t cCefMouseEvent;
    cCefMouseEvent.x = origin.x;
    cCefMouseEvent.y = origin.y;
    CefMouseEvent cefMouseEvent(cCefMouseEvent);
    mBrowser->GetHost()->SendMouseWheelEvent(cefMouseEvent, delta.x, delta.y);
}

- (void)sendCEFKeyboardEventForKey:(short)keyCode character:(char16)character {
    cef_key_event_t cCefKeyEvent;
    cCefKeyEvent.type = KEYEVENT_RAWKEYDOWN;
    cCefKeyEvent.character = character;
    cCefKeyEvent.modifiers = 0;
    cCefKeyEvent.windows_key_code = keyCode;    // FIXME(pcwalton)
    cCefKeyEvent.native_key_code = keyCode;
    cCefKeyEvent.is_system_key = false;
    cCefKeyEvent.focus_on_editable_field = false;
    CefKeyEvent keyEvent(cCefKeyEvent);
    mBrowser->GetHost()->SendKeyEvent(keyEvent);
}

- (void)setIsLoading:(BOOL)isLoading {
    [[[self.tabView selectedTabViewItem] identifier] setValue:[NSNumber numberWithBool:isLoading]
                                                   forKeyPath:@"isProcessing"];
    
    // For some reason the tab view will sometimes make the progress indicator be one pixel too
    // tall. This is really ugly, so we fix that manually by hammering in a square shape.
    NSProgressIndicator *indicator = [[self.tabBar lastAttachedButton] indicator];
    NSSize indicatorSize = [indicator frame].size;
    CGFloat indicatorLength = MIN(indicatorSize.width, indicatorSize.height);
    [indicator setFrameSize:NSMakeSize(indicatorLength, indicatorLength)];
    
    if (!isLoading) {
        [self.statusBarWindow orderOut:self];
        return;
    }
    
    [self.statusBar setStringValue:@"Loading…"];
    [self.statusBar sizeToFit];
    NSSize statusBarSize = NSMakeSize([self.statusBar frame].size.width + 8.0,
                                      [self.statusBar frame].size.height + 6.0);
    [self.statusBar setFrameSize: statusBarSize];
    [self.statusBarWindow setFrame:NSMakeRect([self.statusBarWindow frame].origin.x,
                                              [self.statusBarWindow frame].origin.y,
                                              statusBarSize.width,
                                              statusBarSize.height)
                           display:YES];
    [self.statusBarWindow orderFront:self];
}

- (void)updateNavigationState:(id)unused {
    //[self.backForwardButton setEnabled:canGoBack forSegment:BACK_SEGMENT];
    //[self.backForwardButton setEnabled:canGoForward forSegment:FORWARD_SEGMENT];
    if (mBrowser == nullptr)
        return;
    if ([self.window firstResponder] != self.urlBar || [[self.urlBar stringValue] length] == 0) {
        CefRefPtr<CefFrame> frame = mBrowser->GetMainFrame();
        if (frame != nullptr) {
            NSString *url = [NSString stringWithCEFString: mBrowser->GetMainFrame()->GetURL()];
            if (url != nil && [url length] > 0)
                [self setDisplayedURL:url];
        }
    }
}

- (void)initializeCompositing {
    mBrowser->GetHost()->InitializeCompositing();
    mBrowser->GetHost()->WasResized();
}

- (IBAction)zoomToActualSize:(id)sender {
    mBrowser->GetHost()->SetZoomLevel(1.0);
    [self updateZoomMenuItems];
}

- (IBAction)zoomIn:(id)sender {
    [self pinchZoom: 1.25];
}

- (IBAction)zoomOut:(id)sender {
    [self pinchZoom: 1.0/1.25];
}

- (void)updateZoomMenuItems {
    [self.actualSizeMenuItem setEnabled: fabs(mBrowser->GetHost()->GetZoomLevel() - 1.0) > 0.01];
}

- (void)pinchZoom:(CGFloat)zoomLevel {
    mBrowser->GetHost()->SetZoomLevel(mBrowser->GetHost()->GetZoomLevel() * zoomLevel);
    [self updateZoomMenuItems];
}

- (IBAction)bookmarkCurrentPageOrShowBookmarksPopover:(id)sender {
    NSSegmentedControl* control = (NSSegmentedControl*)sender;
    switch ([control selectedSegment]) {
        case BOOKMARK_SEGMENT:
            [self bookmarkCurrentPage:sender];
            break;
        case SHOW_BOOKMARKS_SEGMENT:
            [self showBookmarksPopover];
            break;
    }
}

- (IBAction)bookmarkCurrentPage:(id)sender {
    MSBookmark *bookmark =
        [[MSBookmark alloc] initWithEntity:
         [NSEntityDescription entityForName:@"MSBookmark"
                     inManagedObjectContext:self.managedObjectContext]
            insertIntoManagedObjectContext:self.managedObjectContext];
    NSString *url = [NSString stringWithCEFString:mBrowser->GetMainFrame()->GetURL()];
    bookmark.url = url;
    bookmark.title = url;
    [self.managedObjectContext save:nil];
}

- (void)showBookmarksPopover {
    mBookmarksPopover = [[NSPopover alloc] init];
    NSViewController *viewController = [[NSViewController alloc] init];
    [viewController setView:self.bookmarksPopoverView];
    [mBookmarksPopover setContentViewController:viewController];
    [mBookmarksPopover showRelativeToRect:NSMakeRect(25.0, 0, 0, 0)
                                   ofView:self.bookmarksButton
                            preferredEdge:NSMaxYEdge];
}

- (void)menuDidOpen:(NSNotification *)notification {
    // FIXME(pcwalton): This is pretty coarse grained. Can we be lazier and only populate the menu
    // that the user selected?
    [self performSelectorInBackground:@selector(populateHistoryMenu:) withObject:nil];
    [self performSelectorInBackground:@selector(populateBookmarksMenu:) withObject:nil];
}

- (void)populateBookmarksMenu:(id)unused {
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] init];
    managedObjectContext.persistentStoreCoordinator = mPersistentStoreCoordinator;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"MSBookmark"
                                        inManagedObjectContext:managedObjectContext]];
    NSArray *bookmarks = [managedObjectContext executeFetchRequest:fetchRequest
                                                             error:nil];
    NSMutableArray *bookmarkIDs = [[NSMutableArray alloc] init];
    for (MSBookmark *bookmark in bookmarks)
        [bookmarkIDs addObject:[bookmark objectID]];
    [self performSelectorOnMainThread:@selector(replaceBookmarkMenuItemsWith:)
                           withObject:bookmarkIDs
                        waitUntilDone:NO];
}

- (void)populateHistoryMenu:(id)unused {
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] init];
    managedObjectContext.persistentStoreCoordinator = mPersistentStoreCoordinator;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"MSHistoryEntry"
                                        inManagedObjectContext:managedObjectContext]];
    [fetchRequest setFetchLimit:HISTORY_MENU_SIZE];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
                                      [NSSortDescriptor sortDescriptorWithKey:@"date"
                                                                    ascending:NO]]];
    NSArray *historyEntries = [managedObjectContext executeFetchRequest:fetchRequest
                                                                  error:nil];
    NSMutableArray *historyEntryIDs = [[NSMutableArray alloc] init];
    for (MSHistoryEntry *historyEntry in historyEntries)
        [historyEntryIDs addObject:[historyEntry objectID]];
    [self performSelectorOnMainThread:@selector(replaceHistoryMenuItemsWith:)
                           withObject:historyEntryIDs
                        waitUntilDone:NO];
}

- (void)replaceBookmarkMenuItemsWith:(NSArray *)bookmarkIDs {
    [self replaceBookmarkOrHistoryItemsInMenu:self.bookmarksMenu withItemIDs:bookmarkIDs];
}

- (void)replaceHistoryMenuItemsWith:(NSArray *)historyEntryIDs {
    [self replaceBookmarkOrHistoryItemsInMenu:self.historyMenu withItemIDs:historyEntryIDs];
}

- (void)replaceBookmarkOrHistoryItemsInMenu:(NSMenu *)menu withItemIDs:(NSArray *)itemIDs {
    while (YES) {
        NSMenuItem *menuItemToDelete = [menu itemWithTag:BOOKMARKS_TAG];
        if (menuItemToDelete == nil)
            break;
        [menu removeItem:menuItemToDelete];
    }
    
    if ([itemIDs count] > 0) {
        NSMenuItem *separator = [NSMenuItem separatorItem];
        [separator setTag:BOOKMARKS_TAG];
        [menu addItem:separator];
    }
    for (NSManagedObjectID *itemID in itemIDs) {
        id<MSBookmarkOrHistoryEntry> item =
            (id<MSBookmarkOrHistoryEntry>)[self.managedObjectContext objectWithID:itemID];
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:item.title
                                                          action:@selector(navigateToBookmark:)
                                                   keyEquivalent:@""];
        [menuItem setTag:BOOKMARKS_TAG];
        [menuItem setTarget:self];
        [menuItem setRepresentedObject:item.url];
        [menuItem setImage:[[NSBundle mainBundle] imageForResource:@"DefaultFavIcon"]];
        [menu addItem:menuItem];
    }
}

- (void)navigateToBookmark:(id)sender {
    [self navigateToURL:[NSURL URLWithString:[sender representedObject]]];
}

- (void)navigateToURL:(NSURL *)url {
    CefString cefString([[url absoluteString] UTF8String]);
    if (mBrowser == nullptr)
        return;
    if (mBrowser->GetMainFrame() == nullptr)
        return;
    mBrowser->GetMainFrame()->LoadURL(cefString);
}

- (void)closePopoversIfNecessary:(NSEvent *)event {
    if (mBookmarksPopover != nil) {
        NSPoint point = [self.bookmarksPopoverView convertPoint:[event locationInWindow]
                                                       fromView:nil];
        if (![self.bookmarksPopoverView mouse:point inRect:[self.bookmarksPopoverView bounds]]) {
            [mBookmarksPopover close];
            mBookmarksPopover = nil;
        }
    }

    if ([self.splendidBarWindow isVisible] && [event window] != self.splendidBarWindow)
        [self.splendidBarWindow orderOut:self];
}

- (void)navigateToBookmarkAtIndex:(NSInteger)index {
    [mBookmarksPopover close];
    mBookmarksPopover = nil;

    MSBookmark *bookmark =
        [[self.bookmarksButtonArrayController arrangedObjects] objectAtIndex:index];
    [self navigateToURL:[NSURL URLWithString:bookmark.url]];
}

- (void)reportBug:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:REPORT_BUG_URL]];
}

- (void)textView:(NSTextView *)textView
   clickedOnCell:(id<NSTextAttachmentCell>)cell
          inRect:(NSRect)cellFrame {
    MSSearchResultCell *searchResultCell = (MSSearchResultCell *)cell;
    [self searchFor: searchResultCell.text];
    [self.splendidBarWindow orderOut:self];
}

- (void)searchFor:(NSString *)query {
    NSString *escapedQuery = [MSAppDelegate URLEncode:query];
    [self navigateToURL:[NSURL URLWithString:
                         [SEARCH_URL stringByReplacingOccurrencesOfString:@"${QUERY}"
                                                               withString:escapedQuery]]];
}

- (void)addHistoryEntryForMainFrame:(id)unused {
    // Add the history entry to Core Data.
    MSHistoryEntry *entry =
    [[MSHistoryEntry alloc] initWithEntity:
            [NSEntityDescription entityForName:@"MSHistoryEntry"
                        inManagedObjectContext:self.managedObjectContext]
            insertIntoManagedObjectContext:self.managedObjectContext];
    entry.url = [NSString stringWithCEFString:mBrowser->GetMainFrame()->GetURL()];
    entry.title = entry.url;
    entry.date = [NSDate date];
    [self.managedObjectContext save:nil];
    
    // Add the history entry to the search index.
    SKDocumentRef document =
        SKDocumentCreateWithURL((__bridge CFURLRef)[NSURL URLWithString:entry.url]);
    SKIndexAddDocumentWithText(mSearchIndex,
                               document,
                               (__bridge CFStringRef)[NSString stringWithFormat:@"%@ %@",
                                                      entry.url,
                                                      entry.title],
                               true);
    CFDictionaryRef existingProperties = SKIndexCopyDocumentProperties(mSearchIndex, document);
    NSMutableDictionary *properties;
    if (existingProperties == nullptr) {
        properties = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSArray array],
                      @"visits",
                      nil];
    } else {
        properties = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary *)existingProperties];
    }
    [properties setObject:entry.title forKey:@"title"];
    [properties setObject:[[properties objectForKey:@"visits"] arrayByAddingObject:entry.date]
                   forKey:@"visits"];
    SKIndexSetDocumentProperties(mSearchIndex, document, (__bridge CFDictionaryRef)properties);
}

- (void)performSplendidBarSearch:(NSString *)query {
    SKIndexFlush(mSearchIndex);
    
    NSMutableCharacterSet *separators = [NSMutableCharacterSet punctuationCharacterSet];
    [separators formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray *words = [query componentsSeparatedByCharactersInSet:separators];
    NSMutableString *searchQuery = [[NSMutableString alloc] init];
    BOOL first = YES;
    for (NSString *word in words) {
        if (!first)
            [searchQuery appendString:@" | "];
        else
            first = NO;
        [searchQuery appendFormat:@"%@*", word];
    }
    SKSearchRef search = SKSearchCreate(mSearchIndex, (__bridge CFStringRef)searchQuery, 0);

    NSUInteger totalSearchResultsFound = 0;
    SKDocumentID searchResultDocuments[MS_HISTORY_BOOKMARKS_AUTOCOMPLETE_SIZE];
    float searchResultScores[MS_HISTORY_BOOKMARKS_AUTOCOMPLETE_SIZE];
    Boolean stillGoing;
    do {
        CFIndex searchResultsFoundThisRound;
        stillGoing =
            SKSearchFindMatches(search,
                                MS_HISTORY_BOOKMARKS_AUTOCOMPLETE_SIZE - totalSearchResultsFound,
                                searchResultDocuments,
                                searchResultScores,
                                0,
                                &searchResultsFoundThisRound);
        if (searchResultsFoundThisRound > 0) {
            NSMutableArray *documents = [[NSMutableArray alloc] init];
            for (NSUInteger i = 0; i < searchResultsFoundThisRound; i++)
                [documents addObject:[NSNumber numberWithLong:searchResultDocuments[i]]];
            NSDictionary *splendidBarUpdateInfo =
            [NSDictionary dictionaryWithObjectsAndKeys:documents,
             @"documents",
             [NSNumber numberWithUnsignedInteger:totalSearchResultsFound],
             @"searchResultLocation",
             [NSNumber numberWithUnsignedInteger:searchResultsFoundThisRound],
             @"searchResultLength",
             nil];
            [self performSelectorOnMainThread:
             @selector(updateSplendidBarWithHistoryAndBookmarkInfo:)
                                   withObject:splendidBarUpdateInfo
                                waitUntilDone:NO];
        }
        totalSearchResultsFound += searchResultsFoundThisRound;
    } while (stillGoing);
}

- (void)updateSplendidBarWithHistoryAndBookmarkInfo:(NSDictionary *)info {
    NSArray *documents = (NSArray *)[info objectForKey:@"documents"];
    NSUInteger searchResultLocation =
        [[info objectForKey:@"searchResultLocation"] unsignedIntegerValue];
    NSUInteger searchResultLength =
        [[info objectForKey:@"searchResultLength"] unsignedIntegerValue];
    NSUInteger searchResultEnd = searchResultLocation + searchResultLength;
    
    for (NSUInteger i = searchResultLocation; i < searchResultEnd; i++)
        [mSplendidBarHistoryAndBookmarkEntryViews replaceObjectAtIndex:i withObject:[NSNull null]];
    
    NSUInteger i = searchResultLocation;
    for (NSNumber *cocoaDocumentID in documents) {
        SKDocumentID documentID = [cocoaDocumentID longValue];
        SKDocumentRef document = SKIndexCopyDocumentForDocumentID(mSearchIndex, documentID);
        NSDictionary *properties =
            (__bridge NSDictionary *)SKIndexCopyDocumentProperties(mSearchIndex, document);
        MSSplendidBarResultView *resultView =
            [[MSSplendidBarResultView alloc] initWithFrame:NSMakeRect(0.0,
                                                                      200.0,
                                                                      300.0,
                                                                      SPLENDID_BAR_ROW_HEIGHT)];
        [resultView setAutoresizingMask:NSViewWidthSizable];
        [resultView setDrawsBackground:NO];
        resultView.splendidBarResultDelegate = self;
        resultView.representedObject = (__bridge NSURL *)SKDocumentCopyURL(document);
        NSMutableAttributedString *resultText = [resultView textStorage];
        [resultText replaceCharactersInRange:NSMakeRange(0, [resultText length]) withString:@""];
        
        // Set up formatting.
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.tabStops =
        [NSArray arrayWithObjects:
         [[NSTextTab alloc] initWithType:NSLeftTabStopType location:7.0],
         [[NSTextTab alloc] initWithType:NSLeftTabStopType location:37.0],
         nil];
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:12.0],
                                    NSFontAttributeName,
                                    paragraphStyle,
                                    NSParagraphStyleAttributeName,
                                    nil];
        
        // Add the image.
        [resultText appendAttributedString:[[NSAttributedString alloc] initWithString:@"\t"
                                                                           attributes:attributes]];
        NSTextAttachment *imageAttachment = [[NSTextAttachment alloc] init];
        NSTextAttachmentCell *imageAttachmentCell = [[NSTextAttachmentCell alloc] init];
        [imageAttachmentCell setImage:[NSImage imageNamed:@"DefaultFavIcon"]];
        [imageAttachment setAttachmentCell:imageAttachmentCell];
        NSMutableAttributedString *attachmentString =
        [[NSMutableAttributedString alloc] initWithAttributedString:
         [NSAttributedString attributedStringWithAttachment:imageAttachment]];
        [attachmentString addAttributes:attributes range:NSMakeRange(0, [attachmentString length])];
        [resultText appendAttributedString:attachmentString];
        
        // Add the title.
        [resultText appendAttributedString:[[NSAttributedString alloc] initWithString:@"\t"
                                                                           attributes:attributes]];
        [resultText appendAttributedString:
         [[NSAttributedString alloc] initWithString:[properties objectForKey:@"title"]
                                         attributes:attributes]];
        
        [mSplendidBarHistoryAndBookmarkEntryViews replaceObjectAtIndex:i withObject:resultView];
        i++;
    }

    [self.splendidBarTableView reloadData];
    [self.splendidBarTableView beginUpdates];
    NSUInteger previousRowCount = [self.splendidBarTableView numberOfRows];
    if (previousRowCount < searchResultEnd + 1) {
        [self.splendidBarTableView insertRowsAtIndexes:
         [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(previousRowCount, searchResultEnd + 1)]
                                         withAnimation:NSTableViewAnimationEffectFade];
    }
    [self.splendidBarTableView endUpdates];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    SKIndexFlush(mSearchIndex);
}

- (void)resetBrowser:(id)sender {
    if (NSRunAlertPanel(@"Are you sure you want to reset MiniServo?",
                        @"Resetting MiniServo will clear history, bookmarks, and preferences. You "
                          @"can't undo this operation.",
                        @"OK",
                        @"Cancel",
                        nil) != NSOKButton) {
        return;
    }
    
    // Delete Core Data objects.
    NSURL *miniServoApplicationSupportDirectory = [self getOrCreateApplicationSupportDirectory];
    self.managedObjectContext = nil;
    mManagedObjectModel = nil;
    mPersistentStoreCoordinator = nil;
    [[NSFileManager defaultManager] removeItemAtURL:
     [miniServoApplicationSupportDirectory URLByAppendingPathComponent:@"BookmarksHistory.sqlite"]
                                              error:nil];
    
    // Delete search index.
    SKIndexClose(mSearchIndex);
    mSearchIndex = nil;
    [[NSFileManager defaultManager]
     removeItemAtURL:[miniServoApplicationSupportDirectory
                      URLByAppendingPathComponent:@"BookmarksHistory.skindex"]
     error:nil];

    // Delete preferences.
    // http://stackoverflow.com/questions/8259786/cocoa-resetting-nsuserdefaults
    NSDictionary *preferenceObjects =
        [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    for (NSString *key in preferenceObjects)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self reinitializeDataStores];
    [self reinitializePreferences];
}

- (NSURL *)getOrCreateApplicationSupportDirectory {
    NSArray *applicationSupportDirectory =
    [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                           inDomains:NSUserDomainMask];
    NSURL *miniServoApplicationSupportDirectory =
    [[applicationSupportDirectory objectAtIndex:0]
     URLByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
    [[NSFileManager defaultManager] createDirectoryAtURL:miniServoApplicationSupportDirectory
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil];
    return miniServoApplicationSupportDirectory;
}

- (void)reinitializeDataStores {
    NSURL *miniServoApplicationSupportDirectory = [self getOrCreateApplicationSupportDirectory];
    
    // Set up Core Data.
    self.managedObjectContext = [[NSManagedObjectContext alloc] init];
    mManagedObjectModel =
    [[NSManagedObjectModel alloc] initWithContentsOfURL:
     [[NSBundle mainBundle] URLForResource:@"BookmarksHistoryModel"
                             withExtension:@"momd"]];
    mPersistentStoreCoordinator =
    [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mManagedObjectModel];
    [mPersistentStoreCoordinator
     addPersistentStoreWithType:NSSQLiteStoreType
     configuration:nil
     URL:[miniServoApplicationSupportDirectory URLByAppendingPathComponent:
          @"BookmarksHistory.sqlite"]
     options:nil
     error:nil];
    self.managedObjectContext.persistentStoreCoordinator = mPersistentStoreCoordinator;
    
    // Set up Search Kit.
    CFURLRef indexURL = (__bridge CFURLRef)[miniServoApplicationSupportDirectory URLByAppendingPathComponent:@"BookmarksHistory.skindex"];
    mSearchIndex = SKIndexOpenWithURL(indexURL, CFSTR("BookmarksHistory"), true);
    if (mSearchIndex == nullptr) {
        mSearchIndex = SKIndexCreateWithURL(indexURL,
                                            CFSTR("BookmarksHistory"),
                                            kSKIndexInverted,
                                            nullptr);
    }

}

- (void)reinitializePreferences {
    // Set up preferences.
    int hyperthreadCount;
    size_t hyperthreadCountSize = sizeof(hyperthreadCount);
    sysctlbyname("hw.ncpu", &hyperthreadCount, &hyperthreadCountSize, nullptr, 0);
    for (int i = 1; i <= hyperthreadCount; i++)
        [self.renderingThreadsView addItemWithObjectValue:[NSNumber numberWithInt: i]];
    
    NSProgressIndicator *indicator = [[self.tabBar lastAttachedButton] indicator];
    [indicator setAutoresizingMask: NSViewNotSizable];
    [indicator setFrameSize:NSMakeSize(5.0, 5.0)];
    
    while (true) {
        NSString *frameworkPath =
        [[NSUserDefaults standardUserDefaults] stringForKey: @"ServoFrameworkPath"];
        if (frameworkPath != nil && [frameworkPath length] > 0) {
            if (dlopen([frameworkPath cStringUsingEncoding:NSUTF8StringEncoding],
                       RTLD_LAZY) == nullptr) {
                NSRunAlertPanel(@"Failed to open Servo library.",
                                @"%s",
                                @"OK",
                                nil,
                                nil,
                                dlerror());
            } else {
                break;
            }
        }
        
        NSString *newFrameworkPath = [self promptForNewFrameworkPath];
        if (newFrameworkPath == nil)
            exit(0);
        [[NSUserDefaults standardUserDefaults] setObject: newFrameworkPath
                                                  forKey: @"ServoFrameworkPath"];
    }
}

- (void)splendidBarResultViewReceivedClick:(MSSplendidBarResultView *)view {
    [self navigateToURL:(NSURL *)view.representedObject];
    [self.splendidBarWindow orderOut:self];
}

- (void)arrowKeyDown:(NSEvent *)event {
    if (![self.window isKeyWindow])
        return;
    if ([self.window firstResponder] != [self.urlBar currentEditor])
        return;
    NSIndexSet *rowsToSelect;
    NSUInteger selectedRow = [self.splendidBarTableView selectedRow];
    if ([event keyCode] == KEY_CODE_DOWN) {
        if (selectedRow == [self.splendidBarTableView numberOfRows] - 1)
            rowsToSelect = [NSIndexSet indexSetWithIndex:selectedRow];
        else
            rowsToSelect = [NSIndexSet indexSetWithIndex:selectedRow + 1];
    } else {
        if (selectedRow == 0)
            rowsToSelect = [NSIndexSet indexSet];
        else
            rowsToSelect = [NSIndexSet indexSetWithIndex:selectedRow - 1];
    }
    [self.splendidBarTableView selectRowIndexes:rowsToSelect byExtendingSelection:NO];
    
    if ([rowsToSelect firstIndex] == NSNotFound)
        return;
    
    NSView *view = [self.splendidBarTableView viewAtColumn:0
                                                       row:[self.splendidBarTableView selectedRow]
                                           makeIfNecessary:YES];
    if (view == nil)
        return;
    if (![[view class] isSubclassOfClass:[MSSplendidBarResultView class]])
        return;
    NSURL *url = (NSURL *)((MSSplendidBarResultView *)view).representedObject;
    [self setDisplayedURL:[url absoluteString]];
    [self.urlBar selectText:self];
}

@end
