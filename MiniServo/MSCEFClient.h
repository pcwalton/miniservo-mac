//
//  MSCEFClient.h
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#ifndef __MiniServo__MSCEFClient__
#define __MiniServo__MSCEFClient__

#import "MSWebView.h"
#include <include/cef_client.h>

@class MSAppDelegate;

class MSCEFClient : public CefClient,
                    public CefLoadHandler,
                    public CefRenderHandler,
                    public CefStringVisitor {
public:
    explicit MSCEFClient(MSAppDelegate* appDelegate, MSWebView* view)
    : mAppDelegate(appDelegate), mView(view) {}

    // CefClient implementation
    virtual CefRefPtr<CefLoadHandler> GetLoadHandler() override;
    virtual CefRefPtr<CefRenderHandler> GetRenderHandler() override;

    // CefLoadHandler implementation
    virtual void OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                                      bool isLoading,
                                      bool canGoBack,
                                      bool canGoForward) override;
    virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           int httpStatusCode) override;
                        
    // CefRenderHandler implementation
    virtual bool GetViewRect(CefRefPtr<CefBrowser> browser, CefRect& rect) override;
    virtual bool GetBackingRect(CefRefPtr<CefBrowser> browser, CefRect& rect) override;
    virtual void OnPaint(CefRefPtr<CefBrowser> browser,
                         CefRenderHandler::PaintElementType type,
                         const CefRenderHandler::RectList& dirtyRects,
                         const void* buffer,
                         int width,
                         int height) override;
    virtual void OnPresent(CefRefPtr<CefBrowser> browser) override;
                        
    // CefStringVisitor implementation (for tab titles)
    virtual void Visit(const CefString& string) override;

private:
    IMPLEMENT_REFCOUNTING(MSCEFClient);
    DISALLOW_COPY_AND_ASSIGN(MSCEFClient);
                        
    MSAppDelegate* mAppDelegate;
    MSWebView* mView;
};

#endif /* defined(__MiniServo__MSCEFClient__) */
