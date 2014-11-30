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
#import "MSSearchResultCell.h"
#import "MSTabModel.h"
#import "MSTabStyle.h"
#import "MSView.h"
#import <MMTabBarView/MMAttachedTabBarButton.h>
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

#define BOOKMARKS_TAG   0xb00c

#define SEARCH_AUTOCOMPLETE_URL \
    @"http://suggestqueries.google.com/complete/search?client=firefox&q=${QUERY}"
#define SEARCH_URL @"http://google.com/search?q=${QUERY}"
#define REPORT_BUG_URL  @"http://github.com/servo/servo/issues"

#define SPLENDID_BAR_TOP_SPACING    3.0

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
                                             selector:@selector(bookmarksMenuDidOpen:)
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
    
    // Create the Application Support directory if necessary.
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
                            URL:[miniServoApplicationSupportDirectory URLByAppendingPathComponent:@"BookmarksHistory.sqlite"]
                        options:nil
                          error:nil];
    self.managedObjectContext.persistentStoreCoordinator = mPersistentStoreCoordinator;

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
    mBrowser = CefBrowserHost::CreateBrowserSync(windowInfo, mCEFClient, INITIAL_URL, browserSettings, nullptr);

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
    NSString *escapedQuery = [MSAppDelegate URLEncode:[self.urlBar stringValue]];
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
    if ([self.splendidBarTableView numberOfRows] > 1) {
        [self.splendidBarTableView removeRowsAtIndexes:
         [NSIndexSet indexSetWithIndexesInRange:
          NSMakeRange(1, [self.splendidBarTableView numberOfRows])]
                                         withAnimation:NSTableViewAnimationEffectFade];
    }
    if ([self.splendidBarTableView numberOfRows] == 0) {
        [self.splendidBarTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:0]
                                         withAnimation:NSTableViewAnimationEffectFade];
    }
    [self.splendidBarTableView endUpdates];
    [self.splendidBarTableView viewAtColumn:0 row:0 makeIfNecessary:YES];
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    if (row == 0)
        return self.splendidBarSearchResultsSectionView;
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
            CefString url = mBrowser->GetMainFrame()->GetURL();
            NSString *nsURL = [[NSString alloc] initWithBytes:url.c_str()
                                                       length:url.length() * 2
                                                     encoding:NSUTF16LittleEndianStringEncoding];
            if (nsURL != nil && [nsURL length] > 0)
                [self setDisplayedURL:nsURL];
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
    CefString cefURL = mBrowser->GetMainFrame()->GetURL();
    NSString *url = [[NSString alloc] initWithBytes:cefURL.c_str()
                                             length:cefURL.length() * 2
                                           encoding:NSUTF16LittleEndianStringEncoding];
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

- (void)bookmarksMenuDidOpen:(id)unused {
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

- (void)replaceBookmarkMenuItemsWith:(NSArray *)bookmarkIDs {
    while (YES) {
        NSMenuItem *menuItemToDelete = [self.bookmarksMenu itemWithTag:BOOKMARKS_TAG];
        if (menuItemToDelete == nil)
            break;
        [self.bookmarksMenu removeItem:menuItemToDelete];
    }
    
    if ([bookmarkIDs count] > 0) {
        NSMenuItem *separator = [NSMenuItem separatorItem];
        [separator setTag:BOOKMARKS_TAG];
        [self.bookmarksMenu addItem:separator];
    }
    for (NSManagedObjectID *bookmarkID in bookmarkIDs) {
        MSBookmark *bookmark = (MSBookmark *)[self.managedObjectContext objectWithID:bookmarkID];
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:bookmark.title
                                                          action:@selector(navigateToBookmark:)
                                                   keyEquivalent:@""];
        [menuItem setTag:BOOKMARKS_TAG];
        [menuItem setTarget:self];
        [menuItem setRepresentedObject:bookmark.url];
        [self.bookmarksMenu addItem:menuItem];
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
        NSPoint point = [self.bookmarksPopoverView convertPoint:[event locationInWindow] fromView:nil];
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

@end
